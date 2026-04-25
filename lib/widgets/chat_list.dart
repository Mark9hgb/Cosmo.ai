import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';

class ChatList extends ConsumerWidget {
  const ChatList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(chatSessionsProvider);
    final currentSessionId = ref.watch(currentSessionProvider);

    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isSelected = session.id == currentSessionId;

        return ListTile(
          leading: Icon(
            Icons.chat_bubble_outline,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          title: Text(
            session.name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            '${session.messages.length} messages',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          selected: isSelected,
          onTap: () {
            ref.read(currentSessionProvider.notifier).state = session.id;
          },
        );
      },
    );
  }
}

final chatSessionsProvider = StateProvider<List<ChatSession>>((ref) => []);
final currentSessionProvider = StateProvider<String?>((ref) => null);

class ChatSession {
  final String id;
  final String name;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSession({
    required this.id,
    required this.name,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });
}