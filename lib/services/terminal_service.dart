import 'dart:async';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TerminalService {
  static const String _pkg = 'com.termux';
  static const String _action = 'com.termux.RUN_COMMAND';
  static const String _extraCmd = 'com.termux.extra.command';
  static const String _extraRunId = 'com.termux.extra.run.id';
  static const String _outPrefix = 'termux_ai_out_';

  static final TerminalService _instance = TerminalService._();
  static TerminalService get instance => _instance;
  TerminalService._();

  final _outputController = StreamController<TerminalOutput>.broadcast();
  Stream<TerminalOutput> get outputStream => _outputController.stream;

  Future<void> initialize() async {}

  Future<bool> isTermuxInstalled() async {
    try {
      final intent = AndroidIntent(action: _action, package: _pkg);
      final result = await intent.canResolveActivity();
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String> executeCommand(String cmd, {String? workdir}) async {
    final ok = await isTermuxInstalled();
    if (!ok) throw Exception('Termux not installed');

    final runId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
    final outFile = '${(await getTemporaryDirectory()).path}/$_outPrefix$runId.txt';

    final intent = AndroidIntent(action: _action, package: _pkg, arguments: {_extraCmd: cmd, _extraRunId: runId});
    await intent.launch();

    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        final f = File(outFile);
        if (await f.exists()) {
          final content = await f.readAsString();
          await f.delete();
          return content;
        }
      } catch (_) {}
    }
    return 'Command timed out';
  }

  void dispose() => _outputController.close();
}

class TerminalOutput {
  final String runId, output;
  final int? exitCode;
  final DateTime timestamp;
  TerminalOutput({required this.runId, required this.output, this.exitCode, DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

final terminalServiceProvider = Provider<TerminalService>((ref) => TerminalService.instance);