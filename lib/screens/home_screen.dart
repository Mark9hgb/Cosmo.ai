import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:xterm/xterm.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/terminal_service.dart';
import '../services/nvidia_nim_service.dart';
import '../services/command_memory_service.dart';
import '../widgets/sidebar.dart';
import '../widgets/chat_list.dart';
import '../widgets/terminal_view.dart';
import '../widgets/settings_panel.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  late Terminal _terminal;
  bool _isLoading = false;
  bool _isThinking = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    WidgetsBinding.instance.addObserver(this);
    _initTerminal();
  }

  Future<void> _initTerminal() async {
    final service = ref.read(terminalServiceProvider);
    await service.initialize();
    _terminal.write('\x1B[1mCosmo AI Terminal\x1B[0m\r\n');
    _terminal.write('Type a message to start...\r\n\r\n');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedTabProvider);
    final sidebarExpanded = ref.watch(sidebarExpandedProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          const CosmoSidebar(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.surface.withOpacity(0.95),
                  ],
                ),
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _buildContent(selectedTab),
                  ),
                  _buildInputBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Cosmo AI',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ).animate(onPlay: (c) => c.repeat()).rotate(duration: 1.seconds),
        ],
      ),
    );
  }

  Widget _buildContent(int selectedTab) {
    switch (selectedTab) {
      case 0:
        return _buildChatView();
      case 1:
        return TerminalViewWidget(terminal: _terminal);
      case 2:
        return const CommandMemoryView();
      case 3:
        return const SettingsPanel();
      default:
        return _buildChatView();
    }
  }

  Widget _buildChatView() {
    final messages = ref.watch(nimMessagesProvider);
    final theme = Theme.of(context);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (_isThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isThinking && index == messages.length) {
          return _buildThinkingIndicator();
        }
        if (index >= messages.length) return const SizedBox.shrink();

        final message = messages[index];
        final isUser = message.role == UserRole.user;

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUser
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    color: isUser
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 30).ms);
      },
    );
  }

  Widget _buildThinkingIndicator() {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(),
            const SizedBox(width: 4),
            _Dot(delay: 150.ms),
            const SizedBox(width: 4),
            _Dot(delay: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                _isLoading ? Icons.hourglass_empty : Icons.send,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    _messageController.clear();
    _focusNode.unfocus();

    ref.read(nimMessagesProvider.notifier).addUserMessage(message);

    setState(() {
      _isLoading = true;
      _isThinking = true;
    });

    try {
      final service = ref.read(nvidiaNimServiceProvider);
      final messages = ref.read(nimMessagesProvider);

      _terminal.writeln('\$ $message');

      final stream = service.sendMessageStream(messages);
      final buffer = StringBuffer();

      await for (final response in stream) {
        buffer.write(response.content);
        ref.read(nimMessagesProvider.notifier).updateLastAssistantMessage(buffer.toString());
        if (mounted) setState(() {});
      }

      final finalContent = buffer.toString();
      if (finalContent.isNotEmpty) {
        ref.read(nimMessagesProvider.notifier).updateLastAssistantMessage(finalContent);
      }
    } catch (e) {
      ref.read(nimMessagesProvider.notifier).addAssistantMessage('Error: $e');
      _terminal.writeln('[Error: $e]');
    } finally {
      setState(() {
        _isLoading = false;
        _isThinking = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(() {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _Dot extends StatelessWidget {
  final Duration delay;
  const _Dot({this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
    ).animate(delay: delay).scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(0.5, 0.5),
          curve: Curves.easeInOut,
        );
  }
}