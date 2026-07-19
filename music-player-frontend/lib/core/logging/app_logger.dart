import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

bool _loggingConfigured = false;

void configureAppLogging() {
  if (_loggingConfigured) return;
  _loggingConfigured = true;

  hierarchicalLoggingEnabled = true;
  Logger.root.level = kDebugMode ? Level.FINE : Level.OFF;

  if (!kDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
    return;
  }

  Logger.root.onRecord.listen((record) {
    final time = record.time.toIso8601String();
    final level = record.level.name;
    final logger = record.loggerName.isEmpty ? 'app' : record.loggerName;
    debugPrintSynchronously('$time [$level] [$logger] ${record.message}');
    if (record.error != null) {
      debugPrintSynchronously('  error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrintSynchronously('${record.stackTrace}');
    }
  });

  debugPrint = (String? message, {int? wrapWidth}) {
    if (message == null || message.isEmpty) return;
    Logger('flutter.debugPrint').fine(message);
  };
}

Future<void> runWithLoggingZone(Future<void> Function() body) {
  final future = runZonedGuarded<Future<void>>(
    body,
    (error, stackTrace) {
      Logger('zone').severe('Unhandled zone error', error, stackTrace);
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        Logger('stdout').info(line);
      },
    ),
  );

  return future ?? Future<void>.value();
}
