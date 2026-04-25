import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/chat_message.dart';

class CommandBlockWidget extends StatelessWidget {
  final CommandBlock commandBlock;
  final VoidCallback? onExecute;
  final VoidCallback? onCopy;
  
  const CommandBlockWidget({
    super.key,
    required this.commandBlock,
    this.onExecute,
    this.onCopy,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasResult = commandBlock.result != null;
    final isExecuting = commandBlock.isExecuting;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.terminal,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  commandBlock.language,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (isExecuting)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ).animate(onPlay: (c) => c.repeat()).rotate()
                else if (!hasResult)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, size: 20),
                    onPressed: onExecute,
                    tooltip: 'Execute',
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: onCopy ?? () => _copyToClipboard(context),
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                commandBlock.command,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (hasResult) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    commandBlock.result!.isSuccess 
                      ? Icons.check_circle 
                      : Icons.error,
                    size: 16,
                    color: commandBlock.result!.isSuccess
                      ? Colors.green
                      : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Exit code: ${commandBlock.result!.exitCode}',
                    style: TextStyle(
                      fontSize: 12,
                      color: commandBlock.result!.isSuccess
                        ? Colors.green
                        : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${commandBlock.result!.duration.inMilliseconds}ms',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: SelectableText(
                  commandBlock.result!.output.isEmpty 
                    ? '(no output)' 
                    : commandBlock.result!.output,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate()
      .fadeIn()
      .slideX(begin: -0.05);
  }
  
  void _copyToClipboard(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Command copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}