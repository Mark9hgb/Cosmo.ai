import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  TerminalService._();

  final _outputController = StreamController<TerminalOutput>.broadcast();
  SharedPreferences? _prefs;

  Stream<TerminalOutput> get outputStream => _outputController.stream;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> _isTermuxInstalled() async {
    try {
      final intent = AndroidIntent(
        action: _termuxRunCommandAction,
        package: _termuxPackage,
      );
      return await intent.canResolveActivity();
    } catch (_) {
      return false;
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String> executeCommand(String command, {String? workdir}) async {
    final termuxInstalled = await _isTermuxInstalled();
    if (!termuxInstalled) {
      throw Exception(
        'Termux is not installed. Please install Termux from F-Droid or Play Store.\n'
        'Also ensure allow-external-apps = true is set in ~/.termux/termux.properties',
      );
    }

    final runId = _generateRunId();
    final outputFilePath = await _getOutputFilePath(runId);
    final scriptPath = await _getTempScriptPath(runId);

    await _writeCommandScript(
      scriptPath: scriptPath,
      command: command,
      workdir: workdir,
    );

    final intent = AndroidIntent(
      action: _termuxRunCommandAction,
      package: _termuxPackage,
      arguments: {
        _extraCommand: 'bash "$scriptPath"',
        _extraRunId: runId,
        if (workdir != null) _extraWorkdir: workdir,
        _extraEnv: {'OUTPUT_FILE': outputFilePath},
      },
    );

    try {
      await intent.launch();
      final result = await _waitForCommandResult(outputFilePath);
      _outputController.add(
        TerminalOutput(
          runId: runId,
          output: result.output,
          exitCode: result.exitCode,
        ),
      );

      if (result.exitCode != 0) {
        throw TerminalException(result.output, result.exitCode);
      }

      return result.output;
    } finally {
      await _cleanupFile(outputFilePath);
      await _cleanupFile(scriptPath);
    }
  }

  Future<void> _writeCommandScript({
    required String scriptPath,
    required String command,
    String? workdir,
  }) async {
    final workdirCommand = workdir == null
        ? ''
        : "cd '${_escapeSingleQuotes(workdir)}' || exit 1\n";

    final scriptContent = '''
#!/data/data/com.termux/files/usr/bin/bash
set +e
$workdirCommand{
$command
} > "\$OUTPUT_FILE" 2>&1
exit_code=\$?
printf '\\n$_exitCodeMarker%s\\n' "\$exit_code" >> "\$OUTPUT_FILE"
''';

    final scriptFile = File(scriptPath);
    await scriptFile.writeAsString(scriptContent);
  }

  String _escapeSingleQuotes(String value) {
    return value.replaceAll("'", "'\"'\"'");
  }

  Future<_CommandResult> _waitForCommandResult(String outputFilePath) async {
    const timeout = Duration(seconds: 120);
    const pollInterval = Duration(seconds: 1);
    final deadline = DateTime.now().add(timeout);
    final outputFile = File(outputFilePath);

    while (DateTime.now().isBefore(deadline)) {
      if (await outputFile.exists()) {
        final content = await outputFile.readAsString();
        final match = RegExp('$_exitCodeMarker\\s*(\\d+)').firstMatch(content);
        if (match != null) {
          final exitCode = int.tryParse(match.group(1)!) ?? 1;
          final output = content
              .replaceFirst(RegExp('$_exitCodeMarker\\s*\\d+\\s*'), '')
              .trimRight();
          return _CommandResult(output: output, exitCode: exitCode);
        }
      }

      await Future.delayed(pollInterval);
    }

    throw TimeoutException(
        'Command timed out after ${timeout.inSeconds} seconds');
  }

  Future<String> executeCommandWithFile(String command, {String? workdir}) {
    return executeCommand(command, workdir: workdir);
  }

  Future<String> getTermuxHomeDirectory() async {
    final prefs = await _getPrefs();
    return prefs.getString('termux_home') ?? '/data/data/com.termux/files/home';
  }

  Future<void> setTermuxHomeDirectory(String path) async {
    final prefs = await _getPrefs();
    await prefs.setString('termux_home', path);
  }

  Future<String?> getLastOutput(String runId) async {
    final outputFilePath = await _getOutputFilePath(runId);
    final file = File(outputFilePath);

    if (await file.exists()) {
      return file.readAsString();
    }
    return null;
  }

  String _generateRunId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'ai_${timestamp}_$random';
  }

  Future<String> _getOutputFilePath(String runId) async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/$_outputFilePrefix$runId.txt';
  }

  Future<String> _getTempScriptPath(String runId) async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/$_outputFilePrefix${runId}_script.sh';
  }

  Future<void> _cleanupFile(String? path) async {
    if (path == null) {
      return;
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore cleanup errors for temporary files.
    }
  }

  Future<bool> checkTermuxConfiguration() async {
    try {
      final result = await executeCommand('echo "TERMUX_CHECK"');
      return result.trim() == 'TERMUX_CHECK';
    } catch (_) {
      return false;
    }
  }

  Future<String> getTermuxVersion() async {
    try {
      final result = await executeCommand('termux-version');
      return result.trim();
    } catch (_) {
      return 'Unknown';
    }
  }

  Stream<List<int>> executeCommandStreaming(String command) async* {
    final output = await executeCommand(command);
    yield utf8.encode(output);
  }

  void dispose() {
    _outputController.close();
  }
}

class _CommandResult {
  final String output;
  final int exitCode;

  const _CommandResult({
    required this.output,
    required this.exitCode,
  });
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
