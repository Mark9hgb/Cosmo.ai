enum UserRole { user, assistant, system }

class ChatMessage {
  final String id;
  final String content;
  final UserRole role;
  final DateTime timestamp;

  ChatMessage({required this.id, required this.content, required this.role, required this.timestamp});

  ChatMessage copyWith({String? id, String? content, UserRole? role, DateTime? timestamp}) {
    return ChatMessage(id: id ?? this.id, content: content ?? this.content, role: role ?? this.role, timestamp: timestamp ?? this.timestamp);
  }
}

class ApiResponse {
  final String content;
  final bool isDelta;
  final bool done;

  ApiResponse({required this.content, this.isDelta = false, this.done = false});
}