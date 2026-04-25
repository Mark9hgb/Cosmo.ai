import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class TerminalViewWidget extends StatelessWidget {
  final Terminal terminal;

  const TerminalViewWidget({super.key, required this.terminal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: TerminalView(
            terminal,
            textStyle: const TerminalStyle(
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            theme: const TerminalTheme(
              cursor: Color(0xFFCCCCCC),
              selection: Color(0x40CCCCCC),
              foreground: Color(0xFFCCCCCC),
              background: Color(0xFF1E1E1E),
              searchHitBackground: Color(0xFF515151),
              searchHitBackgroundCurrent: Color(0xFF515151),
              searchHitForeground: Color(0xFFFFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}