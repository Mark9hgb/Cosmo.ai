import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../services/nvidia_nim_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late Terminal _term;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _term = Terminal();
    _term.write('Cosmo AI Terminal\r\n');
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(nimMessagesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(children: [
        _sidebar(theme),
        Expanded(child: Column(children: [
          Container(height: 56, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))), child: Row(children: [Text('Cosmo AI', style: theme.textTheme.titleMedium), const Spacer(), if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))])),
          Expanded(child: ListView.builder(controller: _scroll, padding: const EdgeInsets.all(16), itemCount: messages.length, itemBuilder: (c, i) {
            final m = messages[i];
            final isUser = m.role == UserRole.user;
            return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isUser ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)), child: Text(m.content)));
          })),
          _input(theme),
        ])),
      ]),
    );
  }

  Widget _sidebar(ThemeData theme) {
    return Container(width: 72, color: theme.colorScheme.surface, child: Column(children: [
      const SizedBox(height: 16),
      _nav(Icons.chat_bubble_outline, 'Chat', 0),
      _nav(Icons.terminal, 'Terminal', 1),
    ]));
  }

  Widget _nav(IconData icon, String label, int index) {
    return IconButton(onPressed: () {}, icon: Icon(icon, size: 24), tooltip: label);
  }

  Widget _input(ThemeData theme) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerColor))), child: Row(children: [
      Expanded(child: TextField(controller: _controller, decoration: InputDecoration(hintText: 'Message...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), fillColor: theme.colorScheme.surfaceContainerHighest), onSubmitted: (_) => _send())),
      const SizedBox(width: 12),
      FloatingActionButton(onPressed: _loading ? null : _send(), child: Icon(_loading ? Icons.hourglass_empty : Icons.send)),
    ]));
  }

  Future<void> _send() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty || _loading) return;
    _controller.clear();
    ref.read(nimMessagesProvider.notifier).addUser(msg);
    setState(() => _loading = true);

    try {
      final svc = ref.read(nvidiaNimServiceProvider);
      final msgs = ref.read(nimMessagesProvider);
      final buf = StringBuffer();
      await for (final r in svc.streamMessages(msgs)) {
        buf.write(r.content);
        if (r.content.isNotEmpty) ref.read(nimMessagesProvider.notifier).updateLast(buf.toString());
        if (mounted) setState(() {});
      }
    } catch (e) {
      ref.read(nimMessagesProvider.notifier).addAssistant('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }
}