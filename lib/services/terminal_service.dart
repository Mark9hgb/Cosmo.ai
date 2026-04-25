import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TerminalService {
  static const String _termuxPackage = 'com.termux';
  static const String _termuxRunCommandAction = 'com.termux.RUN_COMMAND';
  static const String _termuxGetOutputAction = 'com.termux.RUN_COMMAND_GET_OUTPUT';
  
  static const String _extraCommand = 'com.termux.extra.command';
  static const String _extraRunId = 'com.termux.extra.run.id';
  static const String _extraWorkdir = 'com.termux.extra.workdir';
  static const String _extraEnv = 'com.termux.extra.env';
  
  static const String _broadcastAction = 'com.termux.RUN_COMMAND_OUTPUT';
  static const String _extraOutput = 'com.termux.extra.output';
  static const String _extraExitCode = 'com.termux.extra.exit_code';
  
  static TerminalService? _instance;
  static TerminalService get instance => _instance ??= TerminalService._();
  
  TerminalService._();
  
  final _outputController = StreamController<TerminalOutput>.broadcast();
  Stream<TerminalOutput> get outputStream => _outputController.stream;
  
  final Map<String, Completer<String>> _pendingCommands = {};
  final Map<String, DateTime> _commandTimestamps = {};
  
  SharedPreferences? _prefs;
  static const String _outputFilePrefix = 'termux_ai_output_';
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _setupTermuxBroadcastReceiver();
  }
  
  Future<void> _setupTermuxBroadcastReceiver() async {
    const platform = MethodChannel('com.aiassistant.termux_ai_assistant/termux_output');
    
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onCommandOutput') {
        final runId = call.arguments['runId'] as String?;
        final output = call.arguments['output'] as String?;
        final exitCode = call.arguments['exitCode'] as int?;
        
        if (runId != null && _pendingCommands.containsKey(runId)) {
          final completer = _pendingCommands[runId]!;
          _pendingCommands.remove(runId);
          
          if (output != null) {
            completer.complete(output);
          } else if (exitCode != null) {
            completer.completeError(Exception('Command exited with code: $exitCode'));
          }
        }
        
        _outputController.add(TerminalOutput(
          runId: runId ?? '',
          output: output ?? '',
          exitCode: exitCode,
        ));
      }
    });
  }
  
  bool _isTermuxInstalled() async {
    try {
      final androidIntent = AndroidIntent(
        action: _termuxRunCommandAction,
        package: _termuxPackage,
      );
      return await androidIntent.canResolveActivity();
    } catch (e) {
      return false;
    }
  }
  
  Future<String> executeCommand(String command, {String? workdir}) async {
    final termuxInstalled = await _isTermuxInstalled();
    if (!termuxInstalled) {
      throw Exception(
        'Termux is not installed. Please install Termux from F-Droid or Play Store.\n'
        'Also ensure allow-external-apps = true is set in ~/.termux/termux.properties'
      );
    }
    
    final runId = _generateRunId();
    final outputFilePath = await _getOutputFilePath(runId);
    
    final intent = AndroidIntent(
      action: _termuxRunCommandAction,
      package: _termuxPackage,
      arguments: {
        _extraCommand: command,
        _extraRunId: runId,
        if (workdir != null) _extraWorkdir: workdir,
      },
    );
    
    final completer = Completer<String>();
    _pendingCommands[runId] = completer;
    _commandTimestamps[runId] = DateTime.now();
    
    try {
      await intent.launch();
      
      final timeout = Duration(seconds: 120);
      final result = await completer.future.timeout(timeout, 
        onTimeout: () {
          _pendingCommands.remove(runId);
          throw TimeoutException('Command timed out after ${timeout.in seconds} seconds');
        }
      );
      
      await _cleanupOutputFile(outputFilePath);
      return result;
    } catch (e) {
      _pendingCommands.remove(runId);
      await _cleanupOutputFile(outputFilePath);
      rethrow;
    }
  }
  
  Future<String> executeCommandWithFile(String command, {String? workdir}) async {
    final termuxInstalled = await _isTermuxInstalled();
    if (!termuxInstalled) {
      throw Exception(
        'Termux is not installed. Please install Termux from F-Droid or Play Store.\n'
        'Also ensure allow-external-apps = true is set in ~/.termux/termux.properties'
      );
    }
    
    final runId = _generateRunId();
    final outputFilePath = await _getOutputFilePath(runId);
    
    final scriptContent = '''
#!/bin/bash
$command
echo "___EXIT_CODE: \$?" > "$OUTPUT_FILE"
''';
    
    final scriptPath = await _getTempScriptPath(runId);
    await File(scriptPath).writeAsString(scriptContent);
    
    final intent = AndroidIntent(
      action: _termuxRunCommandAction,
      package: _termuxPackage,
      arguments: {
        _extraCommand: 'bash $scriptPath',
        _extraRunId: runId,
        if (workdir != null) _extraWorkdir: workdir,
        _extraEnv: {'OUTPUT_FILE': outputFilePath},
      },
    );
    
    await intent.launch();
    
    var attempts = 0;
    const maxAttempts = 60;
    
    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 2));
      attempts++;
      
      final outputFile = File(outputFilePath);
      if (await outputFile.exists()) {
        final content = await outputFile.readAsString();
        
        final exitCodeMatch = RegExp(r'___EXIT_CODE: (\d+)').firstMatch(content);
        final exitCode = exitCodeMatch != null 
          ? int.tryParse(exitCodeMatch.group(1)!) 
          : null;
        
        final cleanOutput = content.replaceAll(RegExp(r'___EXIT_CODE: \d+'), '').trim();
        
        await _cleanupOutputFile(outputFilePath);
        await _cleanupOutputFile(scriptPath);
        
        if (exitCode != null && exitCode != 0) {
          throw TerminalException(cleanOutput, exitCode);
        }
        
        return cleanOutput;
      }
    }
    
    await _cleanupOutputFile(outputFilePath);
    await _cleanupOutputFile(scriptPath);
    throw TimeoutException('Command timed out waiting for output');
  }
  
  Future<String> getTermuxHomeDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('termux_home') ?? '/data/data/com.termux/files/home';
  }
  
  Future<void> setTermuxHomeDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('termux_home', path);
  }
  
  Future<String?> getLastOutput(String runId) async {
    final outputFilePath = await _getOutputFilePath(runId);
    final file = File(outputFilePath);
    
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }
  
  String _generateRunId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'ai_$timestamp\_$random';
  }
  
  Future<String> _getOutputFilePath(String runId) async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/$_outputFilePrefix$runId.txt';
  }
  
  Future<String> _getTempScriptPath(String runId) async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/$_outputFilePrefix${runId}_script.sh';
  }
  
  Future<void> _cleanupOutputFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }
  
  Future<bool> checkTermuxConfiguration() async {
    try {
      final result = await executeCommand('echo "TERMUX_CHECK"');
      return result.trim() == 'TERMUX_CHECK';
    } catch (e) {
      return false;
    }
  }
  
  Future<String> getTermuxVersion() async {
    try {
      final result = await executeCommand('termux-version');
      return result.trim();
    } catch (e) {
      return 'Unknown';
    }
  }
  
  Stream<List<int>> executeCommandStreaming(String command) async* {
    final process = await Process.start('sh', ['-c', command]);
    
    await for (final data in process.stdout.transform(utf8.decoder)) {
      yield data.codeUnits;
    }
    
    await for (final data in process.stderr.transform(utf8.decoder)) {
      yield data.codeUnits;
    }
  }
  
  void dispose() {
    _outputController.close();
    for (final completer in _pendingCommands.values) {
      if (!completer.isCompleted) {
        completer.cancel();
      }
    }
    _pendingCommands.clear();
  }
}

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

class TerminalException implements Exception {
  final String message;
  final int exitCode;
  
  TerminalException(this.message, this.exitCode);
  
  @override
  String toString() => 'TerminalException: $message (exit code: $exitCode)';
}