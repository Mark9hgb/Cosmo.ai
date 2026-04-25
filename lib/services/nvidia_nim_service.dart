import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/chat_message.dart';
import 'models/api_response.dart';

class NvidiaNimService {
  static const String _defaultBaseUrl = 'https://integrate.api.nvidia.com/v1';

  final Dio _dio;
  final String _model;

  NvidiaNimService._({
    required String apiKey,
    String? baseUrl,
    String model = 'nvidia/llama-3.1-nemotron-70b-instruct',
  })  : _model = model,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? _defaultBaseUrl,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 180),
          validateStatus: (status) => status != null && status < 500,
        ));

  factory NvidiaNimService.create({
    required String apiKey,
    String? baseUrl,
    String model = 'nvidia/llama-3.1-nemotron-70b-instruct',
  }) {
    return NvidiaNimService._(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
    );
  }

  static String get systemPrompt => '''
You are an AI assistant with access to a Linux terminal via Termux on Android.
When user asks for terminal commands, output them in code blocks marked as ```bash
The app will automatically execute these commands and return the output.
''';

  Stream<ApiResponse> sendMessageStream(List<ChatMessage> messages, {int? maxTokens}) {
    final controller = StreamController<ApiResponse>();
    _sendRequest(controller, messages, maxTokens).catchError((e) => controller.addError(e));
    return controller.stream;
  }

  Future<void> _sendRequest(StreamController<ApiResponse> controller, List<ChatMessage> messages, int? maxTokens) async {
    try {
      final formattedMessages = <Map<String, String>>[];
      
      formattedMessages.add({'role': 'system', 'content': systemPrompt});
      
      for (final msg in messages) {
        formattedMessages.add({
          'role': msg.role == UserRole.user ? 'user' : 'assistant',
          'content': msg.content,
        });
      }
      
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': _model,
          'messages': formattedMessages,
          'temperature': 0.7,
          'max_tokens': maxTokens ?? 4096,
          'stream': true,
        },
        options: Options(responseType: ResponseType.stream),
      );

      if (response.statusCode != 200) {
        controller.addError(Exception('API error: ${response.statusCode}'));
        controller.close();
        return;
      }

      final responseBody = response.data as ResponseBody;
      final buffer = StringBuffer();

      await for (final chunk in responseBody.stream) {
        final decoded = utf8.decode(chunk);
        buffer.write(decoded);

        final lines = buffer.toString().split('\n');
        buffer.clear();

        for (final line in lines) {
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload.isEmpty || payload == '[DONE]') {
            controller.add(const ApiResponse(content: '', done: true));
            controller.close();
            return;
          }

          final content = _extractContent(payload);
          if (content.isNotEmpty) {
            controller.add(ApiResponse(content: content, isDelta: true));
          }
        }
      }

      controller.add(const ApiResponse(content: '', done: true));
      controller.close();
    } catch (e) {
      controller.addError(e);
    }
  }

  String _extractContent(String payload) {
    try {
      final match = RegExp(r'"content"\s*:\s*"([^"]*)"').firstMatch(payload);
      return match?.group(1) ?? '';
    } catch (_) {
      return '';
    }
  }

  void dispose() => _dio.close();
}

final nvidiaNimServiceProvider = Provider<NvidiaNimService>((ref) {
  throw UnimplementedError('Override in main.dart');
});

final apiKeyProvider = StateProvider<String>((ref) => '');

final nimMessagesProvider = StateNotifierProvider<_NimMessagesNotifier, List<ChatMessage>>((ref) {
  return _NimMessagesNotifier();
});

class _NimMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  _NimMessagesNotifier() : super([]);

  void addUserMessage(String content) {
    state = [
      ...state,
      ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), content: content, role: UserRole.user, timestamp: DateTime.now()),
    ];
  }

  void addAssistantMessage(String content) {
    state = [
      ...state,
      ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), content: content, role: UserRole.assistant, timestamp: DateTime.now()),
    ];
  }

  void updateLastAssistantMessage(String content) {
    if (state.isEmpty || state.last.role != UserRole.assistant) return;
    state = [...state.sublist(0, state.length - 1), state.last.copyWith(content: content)];
  }

  void clearMessages() => state = [];
}