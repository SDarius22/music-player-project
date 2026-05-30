import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

bool _loggingConfigured = false;

void configureAppLogging() {
  if (_loggingConfigured) return;
  _loggingConfigured = true;

  hierarchicalLoggingEnabled = true;
  //Logger.root.level = kDebugMode ? Level.FINE : Level.INFO;
  Logger.root.level =
      Level
          .FINE; // temporarily set to FINE for more detailed logs during development

  // ChunkService and WebRTCService each emit a FINE log per chunk fetched and
  // per peer-discovery/signaling event, which floods the console during
  // playback. Suppress their FINE chatter while keeping warnings, errors, and
  // their [METRIC] info lines.
  Logger('ChunkService').level = Level.INFO;
  Logger('WebRTCService').level = Level.INFO;

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
