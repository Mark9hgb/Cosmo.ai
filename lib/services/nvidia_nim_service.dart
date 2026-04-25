import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';

class NvidiaService {
  final String _apiKey;
  static const String _baseUrl = 'https://integrate.api.nvidia.com/v1';

  NvidiaService(this._apiKey);

  Stream<ApiResponse> streamMessages(List<ChatMessage> messages) {
    final controller = StreamController<ApiResponse>();
    _send(controller, messages);
    return controller.stream;
  }

  Future<void> _send(StreamController<ApiResponse> controller, List<ChatMessage> messages) async {
    try {
      final dio = Dio(BaseOptions(baseUrl: _baseUrl, headers: {'Authorization': 'Bearer $_apiKey', 'Content-Type': 'application/json'}));
      
      final data = <Map<String, String>>[
        {'role': 'system', 'content': 'You are Cosmo AI. Output bash commands in ```bash blocks when needed.'},
        ...messages.map((m) => {'role': m.role == UserRole.user ? 'user' : 'assistant', 'content': m.content}),
      ];

      final response = await dio.post('/chat/completions', data: {'model': 'nvidia/llama-3.1-nemotron-70b-instruct', 'messages': data, 'temperature': 0.7, 'stream': true}, options: Options(responseType: ResponseType.stream));

      if (response.data != null) {
        final body = response.data as ResponseBody;
        final buffer = StringBuffer();
        await for (final chunk in body.stream) {
          buffer.write(utf8.decode(chunk));
          for (final line in buffer.toString().split('\n')) {
            if (line.startsWith('data:')) {
              final content = line.contains('"content"') ? RegExp(r'"content"\s*:\s*"([^"]*)"').firstMatch(line)?.group(1) ?? '' : '';
              if (content.isNotEmpty) controller.add(ApiResponse(content: content));
            }
          }
        }
      }
      controller.add(const ApiResponse(content: '', done: true));
      controller.close();
    } catch (e) {
      controller.addError(e);
    }
  }
}

class _Notifier extends StateNotifier<List<ChatMessage>> {
  _Notifier() : super([]);
  void addUser(String c) => state = [...state, ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), content: c, role: UserRole.user, timestamp: DateTime.now())];
  void addAssistant(String c) => state = [...state, ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), content: c, role: UserRole.assistant, timestamp: DateTime.now())];
  void updateLast(String c) { if (state.isNotEmpty) state = [...state.sublist(0, state.length - 1), state.last.copyWith(content: c)]; }
  void clear() => state = [];
}

final apiKeyProvider = StateProvider<String>((ref) => '');
final nvidiaProvider = StateNotifierProvider<Notifier, List<ChatMessage>>((ref) => Notifier());

typedef Notifier = _Notifier;
// Provider aliases
final nimMessagesProvider = nvidiaProvider;
final nvidiaNimServiceProvider = Provider((ref) => NvidiaService(ref.read(apiKeyProvider));