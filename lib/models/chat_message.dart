import 'package:equatable/equatable.dart';

enum UserRole { user, assistant, system }

class ChatMessage extends Equatable {
  final String id;
  final String content;
  final UserRole role;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
  });

  ChatMessage copyWith({String? id, String? content, UserRole? role, DateTime? timestamp}) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [id, content, role, timestamp];
}

class ApiResponse extends Equatable {
  final String content;
  final bool isDelta;
  final bool done;

  const ApiResponse({required this.content, this.isDelta = false, this.done = false});

  @override
  List<Object?> get props => [content, isDelta, done];
}