import 'package:equatable/equatable.dart';

class AiModel extends Equatable {
  final String id;
  final String name;
  final String displayName;
  final String description;
  final String provider;
  final int contextLength;
  final bool supportsFunctionCalling;
  final bool supportsVision;
  final bool isPremium;
  final DateTime? addedAt;

  const AiModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.provider,
    required this.contextLength,
    this.supportsFunctionCalling = false,
    this.supportsVision = false,
    this.isPremium = false,
    this.addedAt,
  });

  AiModel copyWith({
    String? id,
    String? name,
    String? displayName,
    String? description,
    String? provider,
    int? contextLength,
    bool? supportsFunctionCalling,
    bool? supportsVision,
    bool? isPremium,
    DateTime? addedAt,
  }) {
    return AiModel(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      provider: provider ?? this.provider,
      contextLength: contextLength ?? this.contextLength,
      supportsFunctionCalling: supportsFunctionCalling ?? this.supportsFunctionCalling,
      supportsVision: supportsVision ?? this.supportsVision,
      isPremium: isPremium ?? this.isPremium,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'displayName': displayName,
    'description': description,
    'provider': provider,
    'contextLength': contextLength,
    'supportsFunctionCalling': supportsFunctionCalling,
    'supportsVision': supportsVision,
    'isPremium': isPremium,
    'addedAt': addedAt?.toIso8601String(),
  };

  factory AiModel.fromJson(Map<String, dynamic> json) => AiModel(
    id: json['id'] as String,
    name: json['name'] as String,
    displayName: json['displayName'] as String,
    description: json['description'] as String,
    provider: json['provider'] as String,
    contextLength: json['contextLength'] as int,
    supportsFunctionCalling: json['supportsFunctionCalling'] as bool? ?? false,
    supportsVision: json['supportsVision'] as bool? ?? false,
    isPremium: json['isPremium'] as bool? ?? false,
    addedAt: json['addedAt'] != null ? DateTime.parse(json['addedAt']) : null,
  );

  @override
  List<Object?> get props => [id, name, displayName, description, provider, contextLength, supportsFunctionCalling, supportsVision, isPremium];

  static List<AiModel> get defaultModels => [
    const AiModel(
      id: 'nvidia/llama-3.1-nemotron-70b-instruct',
      name: 'nvidia/llama-3.1-nemotron-70b-instruct',
      displayName: 'Nemotron 70B',
      description: 'High-performance instruction-following model',
      provider: 'NVIDIA',
      contextLength: 128000,
      supportsFunctionCalling: true,
      isPremium: true,
    ),
    const AiModel(
      id: 'nvidia/llama-3.1-nemotron-50k-instruct',
      name: 'nvidia/llama-3.1-nemotron-50k-instruct',
      displayName: 'Nemotron 50K',
      description: 'Fast instruction-following model',
      provider: 'NVIDIA',
      contextLength: 51200,
      supportsFunctionCalling: true,
    ),
    const AiModel(
      id: 'nvidia/llama-3.1-nemotron-8k-instruct',
      name: 'nvidia/llama-3.1-nemotron-8k-instruct',
      displayName: 'Nemotron 8K',
      description: 'Lightweight fast model',
      provider: 'NVIDIA',
      contextLength: 8192,
    ),
    const AiModel(
      id: 'nvidia/llama-3.3-70b-instruct',
      name: 'nvidia/llama-3.3-70b-instruct',
      displayName: 'Llama 3.3 70B',
      description: 'Latest Llama model',
      provider: 'NVIDIA',
      contextLength: 128000,
      supportsFunctionCalling: true,
      isPremium: true,
    ),
    const AiModel(
      id: 'nvidia/llama-3.1-70b-instruct',
      name: 'nvidia/llama-3.1-70b-instruct',
      displayName: 'Llama 3.1 70B',
      description: 'Powerful open model',
      provider: 'NVIDIA',
      contextLength: 128000,
      supportsFunctionCalling: true,
      isPremium: true,
    ),
    const AiModel(
      id: 'mistralai/mixtral-8x7b-instruct-v0.1',
      name: 'mistralai/mixtral-8x7b-instruct-v0.1',
      displayName: 'Mixtral 8x7B',
      description: 'Efficient mixture of experts',
      provider: 'Mistral AI',
      contextLength: 32000,
      supportsFunctionCalling: true,
    ),
    const AiModel(
      id: 'google/gemma-2-27b-it',
      name: 'google/gemma-2-27b-it',
      displayName: 'Gemma 2 27B',
      description: 'Google\'s latest model',
      provider: 'Google',
      contextLength: 8192,
    ),
  ];
}