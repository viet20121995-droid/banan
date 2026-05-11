import 'dart:developer' as developer;

import 'package:logging/logging.dart';

import '../env/env.dart';

/// Initializes the global logger. Call once from `main()` before `runApp`.
void initLogging() {
  Logger.root.level = Env.isProd ? Level.WARNING : Level.ALL;
  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
}

/// Convenience accessor: `log('auth').info('logged in')`.
Logger log(String name) => Logger(name);
