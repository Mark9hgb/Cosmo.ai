import 'dart:async';
import 'android_intent_plus/android_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TerminalOutput {
  final String runId;
  final String output;
  final int? exitCode;
  final DateTime timestamp;
  
  TerminalOutput({
    required this.runId,
    required this.output,
    this.exitCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  bool get isError => exitCode != null && exitCode != 0;
}

class TerminalService {
  static const String _termuxPackage = 'com.termux';
  static const String _termuxRunCommandAction = 'com.termux.RUN_COMMAND';
  static const String _extraCommand = 'com.termux.extra.command';
  static const String _extraRunId = 'com.termux.extra.run.id';
  static const String _extraWorkdir = 'com.termux.extra.workdir';
  static const String _extraEnv = 'com.termux.extra.env';
  static const String _outputFilePrefix = 'termux_ai_output_';
  static const String _exitCodeMarker = '___EXIT_CODE:';

  static TerminalService? _instance;
  static TerminalService get instance => _instance ??= TerminalService._();

  TerminalService._() {
    _outputController = StreamController<TerminalOutput>.broadcast();
  }
  
  late StreamController<TerminalOutput> _outputController;
  SharedPreferences? _prefs;

  Stream<TerminalOutput> get outputStream => _outputController.stream;
  
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> isTermuxInstalled() async {
    try {
      final intent = AndroidIntent(
        action: _termuxRunCommandAction,
        package: _termuxPackage,
      );
      final result = await intent.canResolveActivity();
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String> executeCommand(String command, {String? workdir}) async {
    final termuxInstalled = await isTermuxInstalled();
    if (!termuxInstalled) {
      throw Exception('Termux is not installed');
    }
    
    final runId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
    final outputFilePath = '${(await getTemporaryDirectory()).path}/$_outputFilePrefix$runId.txt';
    
    final intent = AndroidIntent(
      action: _termuxRunCommandAction,
      package: _termuxPackage,
      arguments: {
        _extraCommand: command,
        _extraRunId: runId,
        if (workdir != null) _extraWorkdir: workdir,
      },
    );
    
    await intent.launch();
    
    var attempts = 0;
    while (attempts < 30) {
      await Future.delayed(const Duration(seconds: 1));
      attempts++;
      
      try {
        final file = await _getOutputFile(outputFilePath);
        if (file != null && file.existsSync()) {
          final content = await file.readAsString();
          await file.delete();
          return content;
        }
      } catch (_) {}
    }
    
    return 'Command timed out';
  }

  Future<File?> _getOutputFile(String path) async {
    return File(path).exists() ? File(path) : null;
  }

  void dispose() {
    _outputController.close();
  }
}

class TerminalException implements Exception {
  final String message;
  final int exitCode;
  
  TerminalException(this.message, this.exitCode);
  
  @override
  String toString() => 'TerminalException: $message (exit code: $exitCode)';
}

final terminalServiceProvider = Provider<TerminalService>((ref) {
  return TerminalService.instance;
});