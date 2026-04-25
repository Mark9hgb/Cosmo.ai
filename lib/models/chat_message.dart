import 'dart:convert';
import 'package:equatable/equatable.dart';

enum UserRole { user, assistant, system }

class ChatMessage extends Equatable {
  final String id;
  final String content;
  final UserRole role;
  final DateTime timestamp;
  final bool isStreaming;
  final List<CommandBlock>? commandBlocks;
  final MessageMetadata? metadata;
  
  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isStreaming = false,
    this.commandBlocks,
    this.metadata,
  });
  
  ChatMessage copyWith({
    String? id,
    String? content,
    UserRole? role,
    DateTime? timestamp,
    bool? isStreaming,
    List<CommandBlock>? commandBlocks,
    MessageMetadata? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      commandBlocks: commandBlocks ?? this.commandBlocks,
      metadata: metadata ?? this.metadata,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'role': role.name,
    'timestamp': timestamp.toIso8601String(),
    'isStreaming': isStreaming,
    'commandBlocks': commandBlocks?.map((e) => e.toJson()).toList(),
    'metadata': metadata?.toJson(),
  };
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    content: json['content'] as String,
    role: UserRole.values.firstWhere((e) => e.name == json['role']),
    timestamp: DateTime.parse(json['timestamp'] as String),
    isStreaming: json['isStreaming'] as bool? ?? false,
    commandBlocks: (json['commandBlocks'] as List?)
        ?.map((e) => CommandBlock.fromJson(e))
        .toList(),
    metadata: json['metadata'] != null 
        ? MessageMetadata.fromJson(json['metadata']) 
        : null,
  );
  
  @override
  List<Object?> get props => [id, content, role, timestamp, isStreaming, commandBlocks, metadata];
}

class MessageMetadata extends Equatable {
  final int? tokenCount;
  final int? modelLatency;
  final String? modelUsed;
  final List<String>? tags;
  
  const MessageMetadata({
    this.tokenCount,
    this.modelLatency,
    this.modelUsed,
    this.tags,
  });
  
  Map<String, dynamic> toJson() => {
    'tokenCount': tokenCount,
    'modelLatency': modelLatency,
    'modelUsed': modelUsed,
    'tags': tags,
  };
  
  factory MessageMetadata.fromJson(Map<String, dynamic> json) => MessageMetadata(
    tokenCount: json['tokenCount'],
    modelLatency: json['modelLatency'],
    modelUsed: json['modelUsed'],
    tags: (json['tags'] as List?)?.cast<String>(),
  );
  
  @override
  List<Object?> get props => [tokenCount, modelLatency, modelUsed, tags];
}

class CommandBlock extends Equatable {
  final String command;
  final String language;
  final DateTime? executedAt;
  final CommandResult? result;
  final bool isExecuting;
  
  const CommandBlock({
    required this.command,
    this.language = 'bash',
    this.executedAt,
    this.result,
    this.isExecuting = false,
  });
  
  CommandBlock copyWith({
    String? command,
    String? language,
    DateTime? executedAt,
    CommandResult? result,
    bool? isExecuting,
  }) {
    return CommandBlock(
      command: command ?? this.command,
      language: language ?? this.language,
      executedAt: executedAt ?? this.executedAt,
      result: result ?? this.result,
      isExecuting: isExecuting ?? this.isExecuting,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'command': command,
    'language': language,
    'executedAt': executedAt?.toIso8601String(),
    'result': result?.toJson(),
    'isExecuting': isExecuting,
  };
  
  factory CommandBlock.fromJson(Map<String, dynamic> json) => CommandBlock(
    command: json['command'] as String,
    language: json['language'] as String? ?? 'bash',
    executedAt: json['executedAt'] != null 
        ? DateTime.parse(json['executedAt']) 
        : null,
    result: json['result'] != null 
        ? CommandResult.fromJson(json['result']) 
        : null,
    isExecuting: json['isExecuting'] as bool? ?? false,
  );
  
  @override
  List<Object?> get props => [command, language, executedAt, result, isExecuting];
}

class CommandResult extends Equatable {
  final String output;
  final int exitCode;
  final DateTime completedAt;
  final Duration duration;
  
  const CommandResult({
    required this.output,
    required this.exitCode,
    required this.completedAt,
    required this.duration,
  });
  
  bool get isSuccess => exitCode == 0;
  
  Map<String, dynamic> toJson() => {
    'output': output,
    'exitCode': exitCode,
    'completedAt': completedAt.toIso8601String(),
    'durationMs': duration.inMilliseconds,
  };
  
  factory CommandResult.fromJson(Map<String, dynamic> json) => CommandResult(
    output: json['output'] as String,
    exitCode: json['exitCode'] as int,
    completedAt: DateTime.parse(json['completedAt'] as String),
    duration: Duration(milliseconds: json['durationMs'] as int),
  );
  
  @override
  List<Object?> get props => [output, exitCode, completedAt, duration];
}

class FileItem extends Equatable {
  final String name;
  final String path;
  final FileType type;
  final int size;
  final DateTime modifiedAt;
  final bool isHidden;
  
  const FileItem({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.modifiedAt,
    this.isHidden = false,
  });
  
  bool get isDirectory => type == FileType.directory;
  bool get isFile => type == FileType.file;
  bool get isExecutable => type == FileType.executable;
  
  @override
  List<Object?> get props => [name, path, type, size, modifiedAt, isHidden];
}

enum FileType { file, directory, executable, symlink, unknown }

class NimConfig extends Equatable {
  final String apiKey;
  final String model;
  final String? baseUrl;
  final double temperature;
  final int maxTokens;
  
  const NimConfig({
    required this.apiKey,
    this.model = 'nvidia/llama-3.1-nemotron-70b-instruct',
    this.baseUrl,
    this.temperature = 0.7,
    this.maxTokens = 4096,
  });
  
  @override
  List<Object?> get props => [apiKey, model, baseUrl, temperature, maxTokens];
}

class ChatSession extends Equatable {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final Map<String, dynamic>? metadata;
  
  const ChatSession({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.metadata,
  });
  
  ChatSession copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    Map<String, dynamic>? metadata,
  }) {
    return ChatSession(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      metadata: metadata ?? this.metadata,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((e) => e.toJson()).toList(),
    'metadata': metadata,
  };
  
  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    messages: (json['messages'] as List?)
        ?.map((e) => ChatMessage.fromJson(e))
        .toList() ?? [],
    metadata: json['metadata'],
  );
  
  @override
  List<Object?> get props => [id, name, createdAt, updatedAt, messages, metadata];
}

class Project extends Equatable {
  final String id;
  final String name;
  final String description;
  final String rootPath;
  final List<String> filePaths;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? thumbnailPath;
  
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.rootPath,
    this.filePaths = const [],
    required this.createdAt,
    required this.updatedAt,
    this.thumbnailPath,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'rootPath': rootPath,
    'filePaths': filePaths,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'thumbnailPath': thumbnailPath,
  };
  
  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    rootPath: json['rootPath'] as String,
    filePaths: (json['filePaths'] as List?)?.cast<String>() ?? [],
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    thumbnailPath: json['thumbnailPath'],
  );
  
  @override
  List<Object?> get props => [id, name, description, rootPath, filePaths, createdAt, updatedAt];
}