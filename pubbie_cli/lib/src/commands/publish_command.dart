import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

class PublishCommand extends Command<int> {
  PublishCommand({required Logger logger}) : _logger = logger;

  final Logger _logger;

  @override
  String get description => 'Publishes a package';

  @override
  String get name => 'publish';

  @override
  FutureOr<int> run() async {
    final command = 'dart pub publish';

    final result = await Process.run(
      '/bin/zsh',
      ['-c', 'source ~/.zshrc && $command'],
    );
    // _logger.progress(result.stdout);

    return ExitCode.success.code;
  }
}
