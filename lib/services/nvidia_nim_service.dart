import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/api_response.dart';

class NvidiaNimService {
  static const String _defaultBaseUrl = 'https://integrate.api.nvidia.com/v1';
  
  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;
  final String _model;
  
  NvidiaNimService._({
    required String apiKey,
    String? baseUrl,
    String model = 'nvidia/llama-3.1-nemotron-70b-instruct',
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl ?? _defaultBaseUrl,
        _model = model,
        _dio = Dio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 180);
  }
  
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

\`\`\`bash
command_to_execute
\`\`\`

For multi-line commands:
\`\`\`bash
cd /path/to/directory
python script.py --arg1 value1
echo "Done"
\`\`\`

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

  Stream<ApiResponse> sendMessageStream(List<ChatMessage> messages, {int? maxTokens}) {
    final controller = StreamController<ApiResponse>();
    
    _sendRequest(controller, messages, maxTokens).catchError((e) {
      controller.addError(e);
    });
    
    return controller.stream;
  }
  
  Future<void> _sendRequest(
    StreamController<ApiResponse> controller,
    List<ChatMessage> messages,
    int? maxTokens,
  ) async {
    try {
      final formattedMessages = messages.map((msg) => {
        'role': msg.role == UserRole.user ? 'user' : 'assistant',
        'content': msg.content,
      }).toList();
      
      formattedMessages.insert(0, {
        'role': 'system',
        'content': systemPrompt,
      });
      
      final requestBody = {
        'model': _model,
        'messages': formattedMessages,
        'temperature': 0.7,
        'top_p': 0.95,
        'max_tokens': maxTokens ?? 4096,
        'stream': true,
      };
      
      final response = await _dio.post(
        '/chat/completions',
        data: requestBody,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
          },
        ),
      );
      
      final stream = response.data.stream as Stream;
      
      String fullContent = '';
      String toolCallBuffer = '';
      bool inToolCall = false;
      
      await for (final chunk in stream) {
        final chunkStr = chunk.toString();
        final lines = chunkStr.split('\n');
        
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          if (line.trim() == 'data: [DONE]') {
            if (toolCallBuffer.isNotEmpty) {
              _parseToolCall(controller, toolCallBuffer);
            }
            controller.close();
            return;
          }
          
          final jsonStr = line.substring(6);
          if (jsonStr.isEmpty) continue;
          
          try {
            final data = _parseSseData(jsonStr);
            if (data == null) continue;
            
            final content = data['delta']?['content'] ?? '';
            if (content.isNotEmpty) {
              fullContent += content;
              
              if (content.contains('```bash') || content.contains('```termux')) {
                inToolCall = true;
              }
              
              if (inToolCall) {
                toolCallBuffer += content;
              } else {
                controller.add(ApiResponse(
                  content: content,
                  isDelta: true,
                  done: false,
                ));
              }
              
              if (inToolCall && toolCallBuffer.contains('```') && 
                  toolCallBuffer.contains('```')) {
                _parseToolCall(controller, toolCallBuffer);
                inToolCall = false;
                toolCallBuffer = '';
              }
            }
          } catch (e) {
            // Skip malformed SSE data
          }
        }
      }
      
      controller.add(ApiResponse(
        content: fullContent,
        isDelta: false,
        done: true,
      ));
      controller.close();
    } catch (e) {
      controller.addError(e);
    }
  }
  
  Map<String, dynamic>? _parseSseData(String jsonStr) {
    try {
      final cleaned = jsonStr.replaceFirst(RegExp(r'^data:\s*'), '');
      if (cleaned.isEmpty || cleaned == '[DONE]') return null;
      return _jsonDecode(cleaned);
    } catch (e) {
      return null;
    }
  }
  
  Map<String, dynamic> _jsonDecode(String str) {
    final regex = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}');
    final match = regex.firstMatch(str);
    if (match == null) return {};
    
    final result = <String, dynamic>{};
    final inner = match.group(0)!;
    
    final contentMatch = RegExp(r'"content"\s*:\s*"([^"]*)"').firstMatch(inner);
    if (contentMatch != null) {
      result['content'] = contentMatch.group(1);
    }
    
    final deltaMatch = RegExp(r'"delta"\s*:\s*\{[^}]*\}').firstMatch(inner);
    if (deltaMatch != null) {
      final deltaStr = deltaMatch.group(0)!;
      final deltaContentMatch = RegExp(r'"content"\s*:\s*"([^"]*)"').firstMatch(deltaStr);
      if (deltaContentMatch != null) {
        result['delta'] = {'content': deltaContentMatch.group(1)};
      }
    }
    
    return result;
  }
  
  Future<String> sendMessage(List<ChatMessage> messages, {int? maxTokens}) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    
    final stream = sendMessageStream(messages, maxTokens: maxTokens);
    
    stream.listen(
      (response) {
        buffer.write(response.content);
      },
      onDone: () => completer.complete(buffer.toString()),
      onError: (e) => completer.completeError(e),
    );
    
    return completer.future;
  }
  
  void dispose() {
    _dio.close();
  }
}

final nvidiaNimServiceProvider = Provider<NvidiaNimService>((ref) {
  throw UnimplementedError('Override in main.dart with actual API key');
});

final apiKeyProvider = StateProvider<String>((ref) => '');

final nimMessagesProvider = StateNotifierProvider<NimMessagesNotifier, List<ChatMessage>>((ref) {
  return NimMessagesNotifier(ref);
});

class NimMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  
  NimMessagesNotifier(this._ref) : super([]);
  
  void addUserMessage(String content) {
    state = [
      ...state,
      ChatMessage(
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
        content: content,
        role: UserRole.assistant,
        timestamp: DateTime.now(),
      ),
    ];
  }
  
  void updateLastAssistantMessage(String content) {
    if (state.isEmpty || state.last.role != UserRole.assistant) return;
    
    state = [
      ...state.sublist(0, state.length - 1),
      ChatMessage(
        content: content,
        role: UserRole.assistant,
        timestamp: state.last.timestamp,
      ),
    ];
  }
  
  void clearMessages() {
    state = [];
  }
}