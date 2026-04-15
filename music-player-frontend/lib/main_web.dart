import 'package:flutter/widgets.dart';
import 'package:music_player_frontend/core/logging/app_logger.dart';
import 'package:music_player_frontend/platforms/web/web_app.dart';

Future<void> main() async {
  configureAppLogging();
  await runWithLoggingZone(() async {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const WebApp());
  });
}
