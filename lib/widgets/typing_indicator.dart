import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum IndicatorType { typing, thinking, dots }

class TypingIndicator extends StatefulWidget {
  final IndicatorType type;
  final int dotCount;
  final double dotSize;
  final Color? color;
  
  const TypingIndicator({
    super.key,
    this.type = IndicatorType.dots,
    this.dotCount = 3,
    this.dotSize = 8,
    this.color,
  });
  
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  
  @override
  void initState() {
    super.initState();
    _initAnimations();
  }
  
  void _initAnimations() {
    _controllers = List.generate(
      widget.dotCount,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    
    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();
    
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: 150 * i), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }
  
  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.type == IndicatorType.thinking)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(Icons.psychology, size: 18, color: color)
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1.seconds, color: color.withOpacity(0.3)),
          ),
        Text(
          _getPrefixText(),
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 8),
        ...List.generate(widget.dotCount, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.translate(
                  offset: Offset(0, -4 * _animations[index].value),
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.5 + (_animations[index].value * 0.5)),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }
  
  String _getPrefixText() {
    switch (widget.type) {
      case IndicatorType.typing:
        return 'typing';
      case IndicatorType.thinking:
        return 'thinking';
      case IndicatorType.dots:
        return '';
    }
  }
}

class ThinkingIndicator extends StatelessWidget {
  final String? thought;
  final VoidCallback? onCancel;
  
  const ThinkingIndicator({
    super.key,
    this.thought,
    this.onCancel,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Thinking',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (onCancel != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onCancel,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (thought != null) ...[
            const SizedBox(height: 8),
            Text(
              thought!,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const TypingIndicator(type: IndicatorType.thinking),
        ],
      ),
    ).animate()
      .fadeIn()
      .slideY(begin: 0.1, curve: Curves.easeOut);
  }
}

class MessageStatus extends StatelessWidget {
  final MessageStatusType status;
  final DateTime? timestamp;
  final VoidCallback? onRetry;
  
  const MessageStatus({
    super.key,
    required this.status,
    this.timestamp,
    this.onRetry,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    IconData icon;
    Color color;
    String text;
    
    switch (status) {
      case MessageStatusType.sending:
        icon = Icons.schedule;
        color = theme.colorScheme.primary;
        text = 'Sending...';
      case MessageStatusType.sent:
        icon = Icons.check;
        color = theme.colorScheme.onSurface.withOpacity(0.5);
        text = 'Sent';
      case MessageStatusType.delivered:
        icon = Icons.done_all;
        color = theme.colorScheme.primary;
        text = 'Delivered';
      case MessageStatusType.read:
        icon = Icons.done_all;
        color = theme.colorScheme.primary;
        text = 'Read';
      case MessageStatusType.error:
        icon = Icons.error_outline;
        color = theme.colorScheme.error;
        text = 'Failed';
      case MessageStatusType.pending:
        icon = Icons.hourglass_empty;
        color = theme.colorScheme.onSurface.withOpacity(0.5);
        text = 'Pending';
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == MessageStatusType.sending)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
            ),
          ).animate(onPlay: (c) => c.repeat()).rotate(duration: 1.seconds)
        else
          Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
          ),
        ),
        if (status == MessageStatusType.error && onRetry != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum MessageStatusType { sending, sent, delivered, read, error, pending }

class StreamingText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool showCursor;
  final Color? cursorColor;
  
  const StreamingText({
    super.key,
    required this.text,
    this.style,
    this.showCursor = true,
    this.cursorColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ?? TextStyle(color: theme.colorScheme.onSurface);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(child: SelectableText(text, style: effectiveStyle)),
        if (showCursor)
          Container(
            width: 2,
            height: effectiveStyle.fontSize ?? 14,
            margin: const EdgeInsets.only(left: 2, bottom: 2),
            color: cursorColor ?? theme.colorScheme.primary,
          ).animate(onPlay: (c) => c.repeat())
            .fadeIn(duration: 300.ms)
            .then()
            .fadeOut(duration: 300.ms),
      ],
    );
  }
}

class CommandExecutingIndicator extends StatelessWidget {
  final String command;
  final VoidCallback? onCancel;
  
  const CommandExecutingIndicator({
    super.key,
    required this.command,
    this.onCancel,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ).animate(onPlay: (c) => c.repeat()).rotate(duration: 1.seconds),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Executing command',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  command,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'JetBrainsMono',
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onCancel != null)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, size: 20),
              onPressed: onCancel,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    ).animate()
      .fadeIn()
      .slideX(begin: -0.05);
  }
}

class ProcessingOverlay extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double? progress;
  final VoidCallback? onCancel;
  
  const ProcessingOverlay({
    super.key,
    required this.title,
    this.subtitle,
    this.progress,
    this.onCancel,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (progress != null)
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                ).animate(onPlay: (c) => c.repeat()).rotate(duration: 1.seconds),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onCancel != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: 200.ms);
  }
}