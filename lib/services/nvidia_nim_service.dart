import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/api_response.dart';
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
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? _defaultBaseUrl,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 180),
          ),
        );

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
You are an AI assistant with full access to a Linux terminal environment via Termux on Android.

Capabilites:
- Execute any bash command in Termux
- Create, read, modify, and delete files
- Run code in various languages (Python, Node.js, etc.)
- Install packages with apt, pip, npm
- Manage git repositories
- Compile and run programs

Instructions:
- When the user asks you to perform a task that requires terminal access, analyze what commands are needed
- Output commands in a special code block marked with language identifier "bash" or "termux"
- The app will automatically execute these commands and return the output
- Always explain what you're going to do before executing

Output format for commands:
Use this format for commands to be executed:

```bash
command_to_execute
```

For multi-line commands:
```bash
cd /path/to/directory
python script.py --arg1 value1
echo "Done"
```

Important notes:
- Always check command output for errors
- If a command fails, analyze the error and try alternative approaches
- For file operations, use proper paths (Termux home is at ~/ or /data/data/com.termux/files/home)
- You have access to the full file system with appropriate permissions

Safety guidelines:
- Never execute commands that could damage the device
- Ask for confirmation before destructive operations
- Don't run commands that require root/sudo (not available in Termux without root)

You can also respond normally in chat when terminal access isn't needed.
''';

  Stream<ApiResponse> sendMessageStream(
    List<ChatMessage> messages, {
    int? maxTokens,
  }) async* {
    final formattedMessages = messages
        .map(
          (msg) => <String, String>{
            'role': switch (msg.role) {
              UserRole.user => 'user',
              UserRole.assistant => 'assistant',
              UserRole.system => 'system',
            },
            'content': msg.content,
          },
        )
        .toList();

    formattedMessages.insert(0, {
      'role': 'system',
      'content': systemPrompt,
    });

    final response = await _dio.post(
      '/chat/completions',
      data: {
        'model': _model,
        'messages': formattedMessages,
        'temperature': 0.7,
        'top_p': 0.95,
        'max_tokens': maxTokens ?? 4096,
        'stream': true,
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
        },
      ),
    );

    final responseBody = response.data as ResponseBody;
    var lineBuffer = '';
    var toolCallBuffer = '';
    var bufferingToolCall = false;

    await for (final chunk in responseBody.stream.cast<Uint8List>().transform(utf8.decoder)) {
      lineBuffer += chunk;
      final lines = lineBuffer.split('\n');
      lineBuffer = lines.removeLast();

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (!line.startsWith('data:')) {
          continue;
        }

        final payload = line.substring(5).trim();
        if (payload.isEmpty) {
          continue;
        }

        if (payload == '[DONE]') {
          if (toolCallBuffer.isNotEmpty) {
            yield _parseToolCall(toolCallBuffer);
          }
          yield const ApiResponse(content: '', isDelta: false, done: true);
          return;
        }

        final decoded = _decodePayload(payload);
        if (decoded == null) {
          continue;
        }

        final content = _extractContent(decoded);
        if (content.isEmpty) {
          continue;
        }

        if (bufferingToolCall || _startsToolCall(content)) {
          bufferingToolCall = true;
          toolCallBuffer += content;

          if (_hasCompletedToolCall(toolCallBuffer)) {
            yield _parseToolCall(toolCallBuffer);
            toolCallBuffer = '';
            bufferingToolCall = false;
          }
          continue;
        }

        yield ApiResponse(content: content, isDelta: true, done: false);
      }
    }

    if (toolCallBuffer.isNotEmpty) {
      yield _parseToolCall(toolCallBuffer);
    }
    yield const ApiResponse(content: '', isDelta: false, done: true);
  }

  Map<String, dynamic>? _decodePayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String _extractContent(Map<String, dynamic> payload) {
    final choices = payload['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      return '';
    }

    final delta = firstChoice['delta'];
    if (delta is! Map) {
      return '';
    }

    final content = delta['content'];
    return content is String ? content : '';
  }

  bool _startsToolCall(String content) {
    return content.contains('```bash') ||
        content.contains('```termux') ||
        content.contains('```sh');
  }

  bool _hasCompletedToolCall(String content) {
    return RegExp(r'```(?:bash|termux|sh)[\s\S]*?```').hasMatch(content);
  }

  ApiResponse _parseToolCall(String content) {
    return ApiResponse(content: content, isDelta: true, done: false);
  }

  Future<String> sendMessage(List<ChatMessage> messages,
      {int? maxTokens}) async {
    final buffer = StringBuffer();

    await for (final response
        in sendMessageStream(messages, maxTokens: maxTokens)) {
      if (!response.done) {
        buffer.write(response.content);
      }
    }

    return buffer.toString();
  }

  void dispose() {
    _dio.close();
  }
}

final nvidiaNimServiceProvider = Provider<NvidiaNimService>((ref) {
  throw UnimplementedError('Override in main.dart with actual API key');
});

final apiKeyProvider = StateProvider<String>((ref) => '');

final nimMessagesProvider =
    StateNotifierProvider<NimMessagesNotifier, List<ChatMessage>>((ref) {
  return NimMessagesNotifier();
});

class NimMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  static const Uuid _uuid = Uuid();

  NimMessagesNotifier() : super([]);

  void addUserMessage(String content) {
    state = [
      ...state,
      ChatMessage(
        id: _uuid.v4(),
        content: content,
        role: UserRole.user,
        timestamp: DateTime.now(),
      ),
    ];
  }

  void addAssistantMessage(String content) {
    state = [
      ...state,
      ChatMessage(
        id: _uuid.v4(),
        content: content,
        role: UserRole.assistant,
        timestamp: DateTime.now(),
      ),
    ];
  }

  void updateLastAssistantMessage(String content) {
    if (state.isEmpty || state.last.role != UserRole.assistant) {
      return;
    }

    state = [
      ...state.sublist(0, state.length - 1),
      state.last.copyWith(content: content),
    ];
  }

  void clearMessages() {
    state = [];
  }
}
