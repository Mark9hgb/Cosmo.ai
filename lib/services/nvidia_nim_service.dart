import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';

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

  factory NvidiaNimService.create({required String apiKey, String? baseUrl, String model = 'nvidia/llama-3.1-nemotron-70b-instruct'}) {
    return NvidiaNimService._(apiKey: apiKey, baseUrl: baseUrl, model: model);
  }

  static String get systemPrompt => 'You are Cosmo AI, an AI assistant for terminal operations. When commands are needed, output them in ```bash code blocks.';

  Stream<ApiResponse> sendMessageStream(List<ChatMessage> messages, {int? maxTokens}) {
    final controller = StreamController<ApiResponse>();
    _sendRequest(controller, messages, maxTokens).catchError((e) => controller.addError(e));
    return controller.stream;
  }

  Future<void> _sendRequest(StreamController<ApiResponse> controller, List<ChatMessage> messages, int? maxTokens) async {
    try {
      final formatted = <Map<String, String>>[];
      formatted.add({'role': 'system', 'content': systemPrompt});
      for (final msg in messages) {
        formatted.add({'role': msg.role == UserRole.user ? 'user' : 'assistant', 'content': msg.content});
      }

      final response = await _dio.post(
        '/chat/completions',
        data: {'model': _model, 'messages': formatted, 'temperature': 0.7, 'max_tokens': maxTokens ?? 4096, 'stream': true},
        options: Options(responseType: ResponseType.stream),
      );

      if (response.statusCode != 200) {
        controller.addError(Exception('API error: ${response.statusCode}'));
        controller.close();
        return;
      }

      final body = response.data as ResponseBody;
      final buffer = StringBuffer();

      await for (final chunk in body.stream) {
        buffer.write(utf8.decode(chunk));
        for (final line in buffer.toString().split('\n')) {
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload.isEmpty || payload == '[DONE]') {
            controller.add(const ApiResponse(content: '', done: true));
            controller.close();
            return;
          }
          final content = _extractContent(payload);
          if (content.isNotEmpty) controller.add(ApiResponse(content: content, isDelta: true));
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

final nvidiaNimServiceProvider = Provider<NvidiaNimService>((ref) => throw UnimplementedError('Override in main.dart'));
final apiKeyProvider = StateProvider<String>((ref) => '');

final nimMessagesProvider = StateNotifierProvider<_Notifier, List<ChatMessage>>((ref) => _Notifier());

class _Notifier extends StateNotifier<List<ChatMessage>> {
  _Notifier() : super([]);

  void addUser(String c) => state = [...state, ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), content: c, role: UserRole.user, timestamp: DateTime.now())];
  void addAssistant(String c) => state = [...state, ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), content: c, role: UserRole.assistant, timestamp: DateTime.now())];
  void updateLast(String c) { if (state.isNotEmpty) state = [...state.sublist(0, state.length - 1), state.last.copyWith(content: c)]; }
  void clear() => state = [];
}