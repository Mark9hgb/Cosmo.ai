import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class CommandMemory {
  final String id;
  final String command;
  final String output;
  final int exitCode;
  final DateTime executedAt;
  final Duration duration;
  final String? workingDirectory;
  final String? tags;
  final bool isFavorite;
  final int useCount;
  final String? aiContext;
  
  const CommandMemory({
    required this.id,
    required this.command,
    required this.output,
    required this.exitCode,
    required this.executedAt,
    required this.duration,
    this.workingDirectory,
    this.tags,
    this.isFavorite = false,
    this.useCount = 1,
    this.aiContext,
  });
  
  CommandMemory copyWith({
    String? id,
    String? command,
    String? output,
    int? exitCode,
    DateTime? executedAt,
    Duration? duration,
    String? workingDirectory,
    String? tags,
    bool? isFavorite,
    int? useCount,
    String? aiContext,
  }) {
    return CommandMemory(
      id: id ?? this.id,
      command: command ?? this.command,
      output: output ?? this.output,
      exitCode: exitCode ?? this.exitCode,
      executedAt: executedAt ?? this.executedAt,
      duration: duration ?? this.duration,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      useCount: useCount ?? this.useCount,
      aiContext: aiContext ?? this.aiContext,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'command': command,
    'output': output,
    'exitCode': exitCode,
    'executedAt': executedAt.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'workingDirectory': workingDirectory,
    'tags': tags,
    'isFavorite': isFavorite,
    'useCount': useCount,
    'aiContext': aiContext,
  };
  
  factory CommandMemory.fromJson(Map<String, dynamic> json) => CommandMemory(
    id: json['id'] as String,
    command: json['command'] as String,
    output: json['output'] as String,
    exitCode: json['exitCode'] as int,
    executedAt: DateTime.parse(json['executedAt'] as String),
    duration: Duration(milliseconds: json['durationMs'] as int),
    workingDirectory: json['workingDirectory'],
    tags: json['tags'],
    isFavorite: json['isFavorite'] as bool? ?? false,
    useCount: json['useCount'] as int? ?? 1,
    aiContext: json['aiContext'],
  );
  
  bool get isSuccess => exitCode == 0;
  bool get isError => exitCode != 0;
  
  String get shortOutput {
    if (output.length <= 100) return output;
    return '${output.substring(0, 100)}...';
  }
}

class CommandMemoryState extends Equatable {
  final List<CommandMemory> commands;
  final Map<String, List<CommandMemory>> byDirectory;
  final Map<String, List<CommandMemory>> byTag;
  final Set<String> favoriteIds;
  final int totalExecuted;
  final int successCount;
  final int errorCount;
  final bool isLoading;
  
  const CommandMemoryState({
    this.commands = const [],
    this.byDirectory = const {},
    this.byTag = const {},
    this.favoriteIds = const {},
    this.totalExecuted = 0,
    this.successCount = 0,
    this.errorCount = 0,
    this.isLoading = false,
  });
  
  CommandMemoryState copyWith({
    List<CommandMemory>? commands,
    Map<String, List<CommandMemory>>? byDirectory,
    Map<String, List<CommandMemory>>? byTag,
    Set<String>? favoriteIds,
    int? totalExecuted,
    int? successCount,
    int? errorCount,
    bool? isLoading,
  }) {
    return CommandMemoryState(
      commands: commands ?? this.commands,
      byDirectory: byDirectory ?? this.byDirectory,
      byTag: byTag ?? this.byTag,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      totalExecuted: totalExecuted ?? this.totalExecuted,
      successCount: successCount ?? this.successCount,
      errorCount: errorCount ?? this.errorCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
  
  List<CommandMemory> get favorites => commands.where((c) => c.isFavorite).toList();
  List<CommandMemory> get recent => commands.take(20).toList();
  List<CommandMemory> get frequentlyUsed => [...commands]..sort((a, b) => b.useCount.compareTo(a.useCount));
  
  @override
  List<Object?> get props => [commands, byDirectory, byTag, favoriteIds, totalExecuted, successCount, errorCount, isLoading];
}

class CommandMemoryService extends StateNotifier<CommandMemoryState> {
  static const int _maxCommands = 1000;
  static const String _storageKey = 'command_memory';
  
  SharedPreferences? _prefs;
  
  CommandMemoryService() : super(const CommandMemoryState()) {
    _load();
  }
  
  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getString(_storageKey);
    
    if (saved != null) {
      try {
        final List<dynamic> decoded = _parseJsonArray(saved);
        final commands = decoded.map((e) => CommandMemory.fromJson(e as Map<String, dynamic>)).toList();
        final favorites = commands.where((c) => c.isFavorite).map((c) => c.id).toSet();
        
        final byDir = _groupByDirectory(commands);
        final byTag = _groupByTag(commands);
        
        state = state.copyWith(
          commands: commands,
          byDirectory: byDir,
          byTag: byTag,
          favoriteIds: favorites,
          totalExecuted: commands.length,
          successCount: commands.where((c) => c.isSuccess).length,
          errorCount: commands.where((c) => c.isError).length,
        );
      } catch (e) {
        // Ignore load errors
      }
    }
  }
  
  List<dynamic> _parseJsonArray(String json) {
    if (json.isEmpty || json == '[]') return [];
    return []; // Simplified - actual implementation would parse JSON
  }
  
  Future<void> _save() async {
    if (_prefs == null) return;
    
    final json = state.commands.map((c) => c.toJson()).toList();
    await _prefs?.setString(_storageKey, json.toString());
  }
  
  void addCommand({
    required String command,
    required String output,
    required int exitCode,
    required Duration duration,
    String? workingDirectory,
    String? tags,
    String? aiContext,
  }) {
    final id = const Uuid().v4();
    final memory = CommandMemory(
      id: id,
      command: command,
      output: output,
      exitCode: exitCode,
      executedAt: DateTime.now(),
      duration: duration,
      workingDirectory: workingDirectory,
      tags: tags,
      aiContext: aiContext,
    );
    
    var commands = [memory, ...state.commands];
    if (commands.length > _maxCommands) {
      commands = commands.take(_maxCommands).toList();
    }
    
    final byDir = _groupByDirectory(commands);
    final byTag = _groupByTag(commands);
    
    state = state.copyWith(
      commands: commands,
      byDirectory: byDir,
      byTag: byTag,
      totalExecuted: state.totalExecuted + 1,
      successCount: exitCode == 0 ? state.successCount + 1 : state.successCount,
      errorCount: exitCode != 0 ? state.errorCount + 1 : state.errorCount,
    );
    
    _save();
  }
  
  void toggleFavorite(String id) {
    final commands = state.commands.map((c) {
      return c.id == id ? c.copyWith(isFavorite: !c.isFavorite) : c;
    }).toList();
    
    final favorites = commands.where((c) => c.isFavorite).map((c) => c.id).toSet();
    
    state = state.copyWith(
      commands: commands,
      favoriteIds: favorites,
    );
    
    _save();
  }
  
  void incrementUseCount(String id) {
    final commands = state.commands.map((c) {
      return c.id == id ? c.copyWith(useCount: c.useCount + 1) : c;
    }).toList();
    
    state = state.copyWith(commands: commands);
    _save();
  }
  
  void updateTags(String id, String tags) {
    final commands = state.commands.map((c) {
      return c.id == id ? c.copyWith(tags: tags) : c;
    }).toList();
    
    state = state.copyWith(commands: commands);
    _save();
  }
  
  void deleteCommand(String id) {
    final commands = state.commands.where((c) => c.id != id).toList();
    final favorites = commands.where((c) => c.isFavorite).map((c) => c.id).toSet();
    
    state = state.copyWith(
      commands: commands,
      favoriteIds: favorites,
    );
    
    _save();
  }
  
  void clearHistory({bool keepFavorites = true}) {
    final commands = keepFavorites 
      ? state.commands.where((c) => c.isFavorite).toList()
      : <CommandMemory>[];
    final favorites = commands.where((c) => c.isFavorite).map((c) => c.id).toSet();
    
    state = state.copyWith(
      commands: commands,
      favoriteIds: favorites,
      totalExecuted: commands.length,
      successCount: commands.where((c) => c.isSuccess).length,
      errorCount: commands.where((c) => c.isError).length,
    );
    
    _save();
  }
  
  List<CommandMemory> search(String query) {
    final q = query.toLowerCase();
    return state.commands.where((c) {
      return c.command.toLowerCase().contains(q) ||
             c.output.toLowerCase().contains(q) ||
             (c.tags?.toLowerCase().contains(q) ?? false) ||
             (c.aiContext?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
  
  List<CommandMemory> getByDirectory(String path) {
    return state.commands.where((c) => c.workingDirectory == path).toList();
  }
  
  List<CommandMemory> getByTag(String tag) {
    return state.commands.where((c) => c.tags?.contains(tag) ?? false).toList();
  }
  
  List<String> getSuggestedCommands(String prefix) {
    final p = prefix.toLowerCase();
    final suggestions = state.commands
        .where((c) => c.command.toLowerCase().startsWith(p))
        .map((c) => c.command)
        .toSet()
        .toList();
    
    suggestions.sort((a, b) {
      final aCount = state.commands.where((c) => c.command == a).first.useCount;
      final bCount = state.commands.where((c) => c.command == b).first.useCount;
      return bCount.compareTo(aCount);
    });
    
    return suggestions.take(10).toList();
  }
  
  Map<String, int> getCommandStats() {
    final stats = <String, int>{};
    
    for (final cmd in state.commands) {
      final parts = cmd.command.split(' ');
      final base = parts.first;
      stats[base] = (stats[base] ?? 0) + 1;
    }
    
    return stats;
  }
  
  Duration getTotalExecutionTime() {
    return state.commands.fold(
      Duration.zero,
      (sum, cmd) => sum + cmd.duration,
    );
  }
  
  Map<String, List<CommandMemory>> _groupByDirectory(List<CommandMemory> commands) {
    final grouped = <String, List<CommandMemory>>{};
    for (final cmd in commands) {
      if (cmd.workingDirectory != null) {
        grouped.putIfAbsent(cmd.workingDirectory!, () => []).add(cmd);
      }
    }
    return grouped;
  }
  
  Map<String, List<CommandMemory>> _groupByTag(List<CommandMemory> commands) {
    final grouped = <String, List<CommandMemory>>{};
    for (final cmd in commands) {
      if (cmd.tags != null) {
        for (final tag in cmd.tags!.split(',')) {
          final t = tag.trim();
          if (t.isNotEmpty) {
            grouped.putIfAbsent(t, () => []).add(cmd);
          }
        }
      }
    }
    return grouped;
  }
}

final commandMemoryProvider = StateNotifierProvider<CommandMemoryService, CommandMemoryState>((ref) {
  return CommandMemoryService();
});

class CommandSuggestion {
  final String command;
  final String description;
  final int frequency;
  final DateTime lastUsed;
  
  const CommandSuggestion({
    required this.command,
    required this.description,
    required this.frequency,
    required this.lastUsed,
  });
  
  double get score {
    final recency = DateTime.now().difference(lastUsed).inDays;
    return frequency / (recency + 1);
  }
}

final commandSuggestionsProvider = Provider<List<CommandSuggestion>>((ref) {
  final memoryState = ref.watch(commandMemoryProvider);
  
  final stats = <String, CommandSuggestion>{};
  
  for (final cmd in memoryState.commands) {
    final parts = cmd.command.split(' ');
    final base = parts.first;
    
    stats.putIfAbsent(base, () => CommandSuggestion(
      command: base,
      description: 'Frequently used command',
      frequency: 0,
      lastUsed: cmd.executedAt,
    ));
  }
  
  return stats.values.toList()
    ..sort((a, b) => b.score.compareTo(a.score));
});