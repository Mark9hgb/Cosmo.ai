import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xterm/xterm.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:share_plus/share_plus.dart';
import '../models/chat_message.dart';
import '../services/terminal_service.dart';
import '../services/nvidia_nim_service.dart';
import '../services/project_service.dart';
import '../services/command_memory_service.dart';
import '../utils/theme_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/command_block_widget.dart';
import '../widgets/file_explorer_widget.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/multi_tab_terminal.dart';
import '../widgets/git_integration_widget.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late TabController _tabController;
  late Terminal _terminal;
  late ProjectService _projectService;

  bool _isLoading = false;
  bool _isExecuting = false;
  bool _showThinkingIndicator = false;
  String _currentThought = '';
  final List<CommandBlock> _pendingCommands = [];
  StreamSubscription? _terminalSubscription;

  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _terminal = Terminal(maxLines: 10000);
    _projectService = ProjectService.instance;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  Future<void> _initializeServices() async {
    await _projectService.initialize();
    await ref.read(terminalServiceProvider).initialize();
    _sessions = await _projectService.getSessions();

    if (_sessions.isNotEmpty) {
      _currentSession = _sessions.first;
      for (final msg in _currentSession!.messages) {
        ref.read(nimMessagesProvider.notifier).addAssistantMessage(msg.content);
      }
    }

    _terminal.write('AI Terminal Assistant ready.\r\n');
    _terminal.write('Type a message to start...\r\n\r\n');

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    _terminalSubscription?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    _messageController.clear();
    _focusNode.unfocus();

    final messages = ref.read(nimMessagesProvider);
    ref.read(nimMessagesProvider.notifier).addUserMessage(message);

    if (_currentSession == null) {
      _currentSession = await _projectService.createSession();
    }

    setState(() {
      _isLoading = true;
      _showThinkingIndicator = true;
      _currentThought = '';
    });

    try {
      final service = ref.read(nvidiaNimServiceProvider);
      final updatedMessages = [
        ...messages,
        ChatMessage(
            id: const Uuid().v4(),
            content: message,
            role: UserRole.user,
            timestamp: DateTime.now())
      ];

      _terminal.write('\r\n\$ $message\r\n');
      _terminal.write('─────────────────────────\r\n\r\n');

      final stream = service.sendMessageStream(updatedMessages);

      final buffer = StringBuffer();

      await for (final response in stream) {
        setState(() {
          _currentThought = _generateThought(buffer.toString());
        });

        buffer.write(response.content);
        ref
            .read(nimMessagesProvider.notifier)
            .updateLastAssistantMessage(buffer.toString());

        final detectedCommands = _parseCommandBlocks(buffer.toString());
        for (final cmd in detectedCommands) {
          if (!_pendingCommands.any((p) => p.command == cmd.command)) {
            _pendingCommands.add(cmd);
            await _executeCommand(cmd);
          }
        }

        if (mounted) setState(() {});
      }

      final finalContent = buffer.toString();
      if (finalContent.isNotEmpty) {
        ref
            .read(nimMessagesProvider.notifier)
            .updateLastAssistantMessage(finalContent);
        _currentSession = _currentSession?.copyWith(
          messages: [
            ..._currentSession!.messages,
            ChatMessage(
                id: const Uuid().v4(),
                content: message,
                role: UserRole.user,
                timestamp: DateTime.now()),
            ChatMessage(
                id: const Uuid().v4(),
                content: finalContent,
                role: UserRole.assistant,
                timestamp: DateTime.now()),
          ],
        );
        if (_currentSession != null) {
          await _projectService.updateSession(_currentSession!);
        }
      }
    } catch (e) {
      _terminal.write('\r\n[Error: $e]\r\n');
      ref
          .read(nimMessagesProvider.notifier)
          .addAssistantMessage('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _showThinkingIndicator = false;
      });
      _scrollToBottom();
    }
  }

  String _generateThought(String partialResponse) {
    if (partialResponse.isEmpty) return 'Analyzing your request...';
    if (partialResponse.length < 20) return 'Processing your request...';
    if (partialResponse.contains('```bash'))
      return 'Identified command to execute';
    if (_pendingCommands.isNotEmpty) return 'Executing command in Termux...';
    return 'Generating response...';
  }

  List<CommandBlock> _parseCommandBlocks(String content) {
    final blocks = <CommandBlock>[];
    final regex = RegExp(r'```(?:bash|termux|sh)\s*\n([\s\S]*?)```');

    for (final match in regex.allMatches(content)) {
      final command = match.group(1)?.trim() ?? '';
      if (command.isNotEmpty) {
        blocks.add(CommandBlock(command: command));
      }
    }

    return blocks;
  }

  Future<void> _executeCommand(CommandBlock block) async {
    if (_isExecuting) return;

    setState(() {
      _isExecuting = true;
      final index = _pendingCommands.indexOf(block);
      if (index >= 0) {
        _pendingCommands[index] = block.copyWith(isExecuting: true);
      }
    });

    final terminal = ref.read(terminalServiceProvider);
    final startTime = DateTime.now();

    _terminal.write('\r\n> ${block.command}\r\n');
    _terminal.write('Executing...\r\n');

    try {
      final output = await terminal.executeCommand(block.command);
      final duration = DateTime.now().difference(startTime);

      ref.read(commandMemoryProvider.notifier).addCommand(
            command: block.command,
            output: output,
            exitCode: 0,
            duration: duration,
          );

      _terminal.write('${output.isEmpty ? '(no output)' : output}\r\n');
      _terminal
          .write('\r\n[Completed in ${duration.inSeconds}s, exit code: 0]\r\n');

      setState(() {
        final index = _pendingCommands.indexOf(block);
        if (index >= 0) {
          _pendingCommands[index] = block.copyWith(
            executedAt: DateTime.now(),
            result: CommandResult(
                output: output,
                exitCode: 0,
                completedAt: DateTime.now(),
                duration: duration),
            isExecuting: false,
          );
        }
      });
    } catch (e) {
      _terminal.write('\r\n[Error: $e]\r\n');

      ref.read(commandMemoryProvider.notifier).addCommand(
            command: block.command,
            output: e.toString(),
            exitCode: 1,
            duration: DateTime.now().difference(startTime),
          );

      setState(() {
        final index = _pendingCommands.indexOf(block);
        if (index >= 0) {
          _pendingCommands[index] = block.copyWith(
            executedAt: DateTime.now(),
            result: CommandResult(
                output: e.toString(),
                exitCode: 1,
                completedAt: DateTime.now(),
                duration: DateTime.now().difference(startTime)),
            isExecuting: false,
          );
        }
      });
    } finally {
      setState(() {
        _isExecuting = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _exportSession() async {
    if (_currentSession == null) return;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const ProcessingOverlay(
              title: 'Exporting Session',
              subtitle: 'Preparing your chat export...',
            ));

    try {
      final exportPath = await _projectService.exportSession(_currentSession!);
      Navigator.pop(context);
      await Share.shareXFiles([XFile(exportPath)],
          subject: 'Termux AI Session Export');
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importSession() async {
    final result = await file_picker.FilePicker.platform.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: ['zip', 'json'],
    );
    if (result == null || result.files.isEmpty) return;

    try {
      final imported =
          await _projectService.importSession(result.files.first.path!);
      if (imported != null) {
        _sessions = await _projectService.getSessions();
        setState(() => _currentSession = imported);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported: ${imported.name}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _exportAsMarkdown() async {
    if (_currentSession == null) return;
    final markdown = ExportService.toMarkdown(_currentSession!);
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/${_currentSession!.name}.md';
    await File(filePath).writeAsString(markdown);
    await Share.shareXFiles([XFile(filePath)], subject: 'Termux AI Session');
  }

  Future<void> _exportAsHtml() async {
    if (_currentSession == null) return;
    final html = ExportService.toHtml(_currentSession!);
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/${_currentSession!.name}.html';
    await File(filePath).writeAsString(html);
    await Share.shareXFiles([XFile(filePath)], subject: 'Termux AI Session');
  }

  Future<void> _createNewSession() async {
    final newSession = await _projectService.createSession();
    _sessions = await _projectService.getSessions();
    setState(() => _currentSession = newSession);
    ref.read(nimMessagesProvider.notifier).clearMessages();
  }

  Future<void> _showSessionsDrawer() async {
    _sessions = await _projectService.getSessions();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Chat History',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        Navigator.pop(context);
                        _createNewSession();
                      }),
                  IconButton(
                      icon: const Icon(Icons.upload_file),
                      onPressed: () {
                        Navigator.pop(context);
                        _importSession();
                      }),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  final isSelected = session.id == _currentSession?.id;
                  return ListTile(
                    leading: Icon(
                        isSelected
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null),
                    title: Text(session.name),
                    subtitle: Text('${session.messages.length} messages',
                        style: Theme.of(context).textTheme.bodySmall),
                    trailing: PopupMenuButton<String>(
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                            value: 'export', child: Text('Export')),
                        const PopupMenuItem<String>(
                            value: 'delete', child: Text('Delete')),
                      ],
                      onSelected: (value) async {
                        if (value == 'export') {
                          Navigator.pop(context);
                          _currentSession = session;
                          _exportSession();
                        } else if (value == 'delete') {
                          await _projectService.deleteSession(session.id);
                          _sessions = await _projectService.getSessions();
                          if (_currentSession?.id == session.id) {
                            _currentSession =
                                _sessions.isNotEmpty ? _sessions.first : null;
                            ref
                                .read(nimMessagesProvider.notifier)
                                .clearMessages();
                          }
                          setState(() {});
                        }
                      },
                    ),
                    selected: isSelected,
                    onTap: () {
                      setState(() => _currentSession = session);
                      ref.read(nimMessagesProvider.notifier).clearMessages();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSettingsDrawer() async {
    final themeState = ref.read(themeStateProvider);
    final themeNotifier = ref.read(themeStateProvider.notifier);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Text('Settings',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              _buildSectionTitle('Appearance'),
              ListTile(
                title: const Text('Dark Mode'),
                subtitle: Text(themeState.mode.name.toUpperCase()),
                trailing: SegmentedButton<AppThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: AppThemeMode.light,
                        icon: Icon(Icons.light_mode)),
                    ButtonSegment(
                        value: AppThemeMode.system,
                        icon: Icon(Icons.auto_mode)),
                    ButtonSegment(
                        value: AppThemeMode.dark, icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {themeState.mode},
                  onSelectionChanged: (values) =>
                      themeNotifier.setMode(values.first),
                ),
              ),
              const SizedBox(height: 8),
              _buildSectionTitle('Accent Color'),
              Wrap(
                spacing: 8,
                children: ColorSeed.values.map((seed) {
                  final isSelected = themeState.seedColor == seed;
                  return GestureDetector(
                    onTap: () => themeNotifier.setSeedColor(seed),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: seed.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const Divider(),
              _buildSectionTitle('Glass Effect'),
              Slider(
                value: themeState.glassOpacity,
                min: 0,
                max: 0.3,
                divisions: 6,
                label: 'Opacity: ${(themeState.glassOpacity * 100).round()}%',
                onChanged: (value) => themeNotifier.setGlassOpacity(value),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  themeNotifier.resetToDefaults();
                  Navigator.pop(context);
                },
                child: const Text('Reset to Defaults'),
              ),
              const Divider(),
              _buildSectionTitle('Command Memory'),
              Consumer(
                builder: (context, ref, _) {
                  final memoryState = ref.watch(commandMemoryProvider);
                  return Column(
                    children: [
                      ListTile(
                        title: const Text('Total Commands'),
                        trailing: Text('${memoryState.totalExecuted}'),
                      ),
                      ListTile(
                        title: const Text('Success Rate'),
                        trailing: Text(memoryState.totalExecuted > 0
                            ? '${(memoryState.successCount / memoryState.totalExecuted * 100).round()}%'
                            : 'N/A'),
                      ),
                      ListTile(
                        title: const Text('Favorites'),
                        trailing: Text('${memoryState.favoriteIds.length}'),
                      ),
                      TextButton(
                        onPressed: () => _showCommandMemoryDialog(),
                        child: const Text('View Command History'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  void _showCommandMemoryDialog() {
    final memoryState = ref.read(commandMemoryProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Command Memory'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: memoryState.commands.length,
            itemBuilder: (context, index) {
              final cmd = memoryState.commands[index];
              return ListTile(
                leading: Icon(
                  cmd.isSuccess ? Icons.check_circle : Icons.error,
                  color: cmd.isSuccess ? Colors.green : Colors.red,
                ),
                title: Text(cmd.command,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                subtitle: Text(
                    '${cmd.duration.inMilliseconds}ms • Used ${cmd.useCount}x'),
                trailing: IconButton(
                  icon: Icon(cmd.isFavorite ? Icons.star : Icons.star_border),
                  onPressed: () => ref
                      .read(commandMemoryProvider.notifier)
                      .toggleFavorite(cmd.id),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(commandMemoryProvider.notifier).clearHistory();
              Navigator.pop(context);
            },
            child: const Text('Clear History'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(nimMessagesProvider);
    final themeState = ref.watch(themeStateProvider);
    final theme = Theme.of(context);

    final effectiveTheme = themeState.mode == AppThemeMode.dark
        ? AppTheme.darkTheme(themeState.seedColor,
            glassOpacity: themeState.glassOpacity)
        : AppTheme.lightTheme(themeState.seedColor,
            glassOpacity: themeState.glassOpacity);

    return Theme(
      data: effectiveTheme,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface.withOpacity(0.95),
                theme.colorScheme.surface.withOpacity(0.85),
              ],
            ),
          ),
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildChatView(messages),
                    const MultiTabTerminal(),
                    _buildFileExplorerView(),
                    const GitIntegrationWidget(),
                    _buildCommandMemoryView(),
                  ],
                ),
              ),
              if (_showThinkingIndicator)
                ThinkingIndicator(
                  thought: _currentThought,
                  onCancel: () =>
                      setState(() => _showThinkingIndicator = false),
                ).animate().fadeIn(),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GlassContainer(
      borderRadius: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.menu), onPressed: _showSessionsDrawer),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_currentSession?.name ?? 'New Chat',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (_currentSession != null)
                      Text('${_currentSession!.messages.length} messages',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6))),
                  ],
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _showSettingsDrawer),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                      value: 'export_zip',
                      child: ListTile(
                          leading: Icon(Icons.archive),
                          title: Text('Export as ZIP'),
                          contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem<String>(
                      value: 'export_md',
                      child: ListTile(
                          leading: Icon(Icons.description),
                          title: Text('Export as Markdown'),
                          contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem<String>(
                      value: 'export_html',
                      child: ListTile(
                          leading: Icon(Icons.html),
                          title: Text('Export as HTML'),
                          contentPadding: EdgeInsets.zero)),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                      value: 'new_session',
                      child: ListTile(
                          leading: Icon(Icons.add),
                          title: Text('New Session'),
                          contentPadding: EdgeInsets.zero)),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'export_zip':
                      _exportSession();
                      break;
                    case 'export_md':
                      _exportAsMarkdown();
                      break;
                    case 'export_html':
                      _exportAsHtml();
                      break;
                    case 'new_session':
                      _createNewSession();
                      break;
                  }
                },
              ),
              if (_isLoading || _isExecuting)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .rotate(duration: 1.seconds),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return GlassContainer(
      borderRadius: 0,
      padding: EdgeInsets.zero,
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        indicatorColor: Theme.of(context).colorScheme.primary,
        tabs: const [
          Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
          Tab(icon: Icon(Icons.terminal), text: 'Terminal'),
          Tab(icon: Icon(Icons.folder_outlined), text: 'Files'),
          Tab(icon: Icon(Icons.source), text: 'Git'),
          Tab(icon: Icon(Icons.history), text: 'Memory'),
        ],
      ),
    );
  }

  Widget _buildChatView(List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (_pendingCommands.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && _pendingCommands.isNotEmpty)
          return _buildCommandBlocksList();
        if (index >= messages.length) return const SizedBox.shrink();
        final message = messages[index];
        final isUser = message.role == UserRole.user;
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: GlassContainer(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser && _containsCodeBlock(message.content))
                  _buildCodeContent(message.content)
                else
                  StreamingText(
                      text: message.content,
                      style: TextStyle(
                          color: isUser
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_formatTimestamp(message.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5))),
                    if (!isUser)
                      IconButton(
                          icon: const Icon(Icons.copy, size: 14),
                          onPressed: () => _copyToClipboard(message.content),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Copy'),
                  ],
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(delay: (index * 50).ms)
            .slideX(begin: isUser ? 0.1 : -0.1, delay: (index * 50).ms);
      },
    );
  }

  Widget _buildCodeContent(String content) {
    final codeBlocks = _extractCodeBlocks(content);
    if (codeBlocks.isEmpty) return SelectableText(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < codeBlocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildCodeBlock(codeBlocks[i]),
        ],
      ],
    );
  }

  Widget _buildCodeBlock(String code) {
    return GlassContainer(
      borderRadius: 8,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('bash',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () => _copyToClipboard(code),
                  tooltip: 'Copy'),
              IconButton(
                  icon: const Icon(Icons.play_arrow, size: 16),
                  onPressed: () => _executeCommand(CommandBlock(command: code)),
                  tooltip: 'Execute'),
            ],
          ),
          HighlightView(code,
              language: 'bash',
              theme: githubTheme,
              padding: EdgeInsets.zero,
              textStyle:
                  const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13)),
        ],
      ),
    );
  }

  List<String> _extractCodeBlocks(String content) {
    final blocks = <String>[];
    final regex = RegExp(r'```(?:bash|termux|sh)\s*\n([\s\S]*?)```');
    for (final match in regex.allMatches(content)) {
      final code = match.group(1)?.trim();
      if (code != null && code.isNotEmpty) blocks.add(code);
    }
    return blocks;
  }

  bool _containsCodeBlock(String content) =>
      content.contains('```bash') || content.contains('```termux');

  Widget _buildCommandBlocksList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Executed Commands:',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final cmd in _pendingCommands)
          CommandBlockWidget(
              commandBlock: cmd, onExecute: () => _executeCommand(cmd)),
      ],
    );
  }

  Widget _buildFileExplorerView() {
    return FileExplorerWidget(
        terminalService: ref.read(terminalServiceProvider));
  }

  Widget _buildCommandMemoryView() {
    final memoryState = ref.watch(commandMemoryProvider);
    final stats = ref.watch(commandMemoryProvider.notifier).getCommandStats();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildMemoryStats(memoryState),
          const SizedBox(height: 16),
          _buildCommandStats(stats),
          const SizedBox(height: 16),
          Text('Recent Commands',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final cmd in memoryState.recent)
            ListTile(
              leading: Icon(cmd.isSuccess ? Icons.check_circle : Icons.error,
                  color: cmd.isSuccess ? Colors.green : Colors.red),
              title: Text(cmd.command,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              subtitle: Text(
                  '${cmd.duration.inMilliseconds}ms • ${cmd.useCount}x use'),
              trailing: IconButton(
                  icon: Icon(cmd.isFavorite ? Icons.star : Icons.star_border),
                  onPressed: () => ref
                      .read(commandMemoryProvider.notifier)
                      .toggleFavorite(cmd.id)),
            ),
        ],
      ),
    );
  }

  Widget _buildMemoryStats(CommandMemoryState memoryState) {
    return Row(
      children: [
        Expanded(
            child: _buildStatCard(
                'Total', memoryState.totalExecuted.toString(), Icons.terminal)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildStatCard(
                'Success', memoryState.successCount.toString(), Icons.check,
                color: Colors.green)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildStatCard(
                'Errors', memoryState.errorCount.toString(), Icons.error,
                color: Colors.red)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildStatCard('Favorites',
                memoryState.favoriteIds.length.toString(), Icons.star,
                color: Colors.amber)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon,
      {Color? color}) {
    final theme = Theme.of(context);
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: 12,
      child: Column(
        children: [
          Icon(icon, color: color ?? theme.colorScheme.primary, size: 24),
          const SizedBox(height: 4),
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildCommandStats(Map<String, int> stats) {
    final sortedStats = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCommands = sortedStats.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Most Used Commands',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final entry in topCommands)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(entry.key,
                    style: const TextStyle(fontFamily: 'monospace')),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${entry.value}x',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInputBar() {
    return GlassContainer(
      borderRadius: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              FloatingActionButton(
                onPressed: _isLoading ? null : _sendMessage,
                child: Icon(_isLoading ? Icons.hourglass_empty : Icons.send),
              ).animate(target: _isLoading ? 1 : 0).rotate(),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

final terminalServiceProvider =
    Provider<TerminalService>((ref) => TerminalService.instance);
