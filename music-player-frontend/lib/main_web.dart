import 'package:flutter/widgets.dart';
import 'package:music_player_frontend/platforms/web/web_app.dart';

import 'local_libs/just_audio_media_kit/just_audio_media_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.protocolWhitelist = ["http", "https", "file", "ws", "wss"];
  JustAudioMediaKit.title = 'Music Player';
  JustAudioMediaKit.ensureInitialized(web: true);
  runApp(const WebApp());
}
