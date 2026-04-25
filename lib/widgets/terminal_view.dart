import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class TerminalViewWidget extends StatelessWidget {
  final Terminal terminal;

  const TerminalViewWidget({super.key, required this.terminal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            padding: const EdgeInsets.all(8),
            theme: const TerminalTheme(
              cursor: Color(0xFFCCCCCC),
              selection: Color(0x40CCCCCC),
              foreground: Color(0xFFCCCCCC),
              background: Color(0xFF1E1E1E),
              black: Color(0xFF000000),
              white: Color(0xFFCCCCCC),
              red: Color(0xFFCD3131),
              green: Color(0xFF0DBC79),
              yellow: Color(0xFFE5E510),
              blue: Color(0xFF2472C8),
              magenta: Color(0xFFBC3FBC),
              cyan: Color(0xFF11A8CD),
              brightBlack: Color(0xFF666666),
              brightWhite: Color(0xFFF2F2F2),
              brightRed: Color(0xFFCD3131),
              brightGreen: Color(0xFF0DBC79),
              brightYellow: Color(0xFFE5E510),
              brightBlue: Color(0xFF2472C8),
              brightMagenta: Color(0xFFBC3FBC),
              brightCyan: Color(0xFF11A8CD),
            ),
          ),
        ),
      ),
    );
  }
}