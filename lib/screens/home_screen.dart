import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:xterm/xterm.dart';
import '../models/chat_message.dart';
import '../services/nvidia_nim_service.dart';
import '../services/terminal_service.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  late Terminal _terminal;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal();
    _init();
  }

  Future<void> _init() async {
    final svc = ref.read(terminalServiceProvider);
    await svc.initialize();
    _terminal.write('Cosmo AI Terminal\r\n');
    _terminal.write('Type a message...\r\n\r\n');
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(selectedTabProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(children: [
        const CosmoSidebar(),
        Expanded(child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.colorScheme.surface, theme.colorScheme.surface.withOpacity(0.95)])), child: Column(children: [
          _header(theme),
          Expanded(child: _content(tab)),
          _inputBar(theme),
        ]))),
      ]),
    );
  }

  Widget _header(ThemeData theme) => Container(height: 56, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)))), child: Row(children: [Text('Cosmo AI', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), const Spacer(), if (_isLoading) SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)).animate(onPlay: (c) => c.repeat()).rotate(duration: 1.seconds)]));

  Widget _content(int tab) {
    switch (tab) {
      case 0: return _chatView();
      case 1: return _terminalView();
      case 2: return _memoryView();
      case 3: return _settingsView();
      default: return _chatView();
    }
  }

  Widget _chatView() {
    final msgs = ref.watch(nimMessagesProvider);
    final theme = Theme.of(context);
    return ListView.builder(controller: _scrollController, padding: const EdgeInsets.all(16), itemCount: msgs.length, itemBuilder: (c, i) {
      final msg = msgs[i];
      final isUser = msg.role == UserRole.user;
      return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.of(c).size.width * 0.75), margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isUser ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)), child: Text(msg.content, style: TextStyle(color: isUser ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface)))).animate().fadeIn(delay: (i * 30).ms);
    });
  }

  Widget _terminalView() => Padding(padding: const EdgeInsets.all(16), child: Container(decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: TerminalView(_terminal, textStyle: const TerminalStyle(fontFamily: 'monospace', fontSize: 14), theme: const TerminalTheme(cursor: Color(0xFFCCCCCC), searchHitBackground: Color(0xFF515151), searchHitBackgroundCurrent: Color(0xFF515151), searchHitForeground: Color(0xFFFFFFFF), foreground: Color(0xFFCCCCCC), background: Color(0xFF1E1E1E)))));

  Widget _memoryView() {
    final theme = Theme.of(context);
    return Center(child: Text('No commands executed yet', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))));
  }

  Widget _settingsView() {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeStateProvider);
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Settings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      Text('Theme', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
      Row(children: [
        _themeBtn(AppThemeMode.light, Icons.light_mode, 'Light', themeState),
        _themeBtn(AppThemeMode.dark, Icons.dark_mode, 'Dark', themeState),
        _themeBtn(AppThemeMode.system, Icons.auto_mode, 'System', themeState),
      ]),
    ]));
  }

  Widget _themeBtn(AppThemeMode mode, IconData icon, String label, ThemeState st) {
    final theme = Theme.of(context);
    final sel = st.mode == mode;
    return Expanded(child: GestureDetector(onTap: () => ref.read(themeStateProvider.notifier).setMode(mode), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: sel ? theme.colorScheme.primaryContainer : theme.colorScheme.surface, borderRadius: BorderRadius.circular(8)), child: Column(children: [Icon(icon, color: sel ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface.withOpacity(0.6)), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 12, color: sel ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface.withOpacity(0.6)))]))));
  }

  Widget _inputBar(ThemeData theme) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)))), child: Row(children: [
    Expanded(child: TextField(controller: _msgController, focusNode: _focusNode, maxLines: 4, minLines: 1, decoration: InputDecoration(hintText: 'Type a message...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), onSubmitted: (_) => _send())),
    const SizedBox(width: 12),
    GestureDetector(onTap: _isLoading ? null : _send, child: Container(width: 48, height: 48, decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(24)), child: Icon(_isLoading ? Icons.hourglass_empty : Icons.send, color: Colors.white))),
  ]));

  Future<void> _send() async {
    final msg = _msgController.text.trim();
    if (msg.isEmpty || _isLoading) return;
    _msgController.clear();
    _focusNode.unfocus();
    ref.read(nimMessagesProvider.notifier).addUser(msg);
    setState(() => _isLoading = true);
    try {
      final svc = ref.read(nvidiaNimServiceProvider);
      final msgs = ref.read(nimMessagesProvider);
      _terminal.write('\$ $msg\r\n');
      final buf = StringBuffer();
      await for (final r in svc.sendMessageStream(msgs)) {
        buf.write(r.content);
        ref.read(nimMessagesProvider.notifier).updateLast(buf.toString());
        if (mounted) setState(() {});
      }
    } catch (e) {
      ref.read(nimMessagesProvider.notifier).addAssistant('Error: $e');
      _terminal.write('Error: $e\r\n');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class CosmoSidebar extends ConsumerWidget {
  const CosmoSidebar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectedTabProvider);
    final theme = Theme.of(context);
    final items = [(Icons.chat_bubble_outline, 'Chat', 0), (Icons.terminal, 'Terminal', 1), (Icons.history, 'Memory', 2), (Icons.settings, 'Settings', 3)];
    return Container(width: 72, decoration: BoxDecoration(color: theme.colorScheme.surface, border: Border(right: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)))), child: Column(children: [
      const SizedBox(height: 16),
      ...items.map((i) => _NavItem(icon: i.$1, label: i.$2, sel: sel == i.$3, onTap: () => ref.read(selectedTabProvider.notifier).state = i.$3)),
    ]));
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final bool sel; final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8), child: Material(color: sel ? theme.colorScheme.primaryContainer : Colors.transparent, borderRadius: BorderRadius.circular(12), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), child: Column(children: [Icon(icon, size: 20, color: sel ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface.withOpacity(0.6)), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 10, color: sel ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface.withOpacity(0.6)))]))));
  }
}