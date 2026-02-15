import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/platforms/android/ui/android_app.dart';
import 'package:music_player_frontend/platforms/linux/ui/linux_app.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ObjectBox.initialize();

  JustAudioMediaKit.protocolWhitelist = ["http", "https", "file"];
  JustAudioMediaKit.title = 'Music Player';
  JustAudioMediaKit.ensureInitialized(linux: true, windows: true);
  switch (Platform.operatingSystem) {
    case 'android':
      await [
        Permission.mediaLibrary,
        Permission.audio,
        Permission.storage,
      ].request();
      debugPrint('Running on Android');
      runApp(const AndroidApp());
      break;
    case 'windows':
      debugPrint('Running on Windows');
      break;
    case 'linux':
      debugPrint('Running on Linux');
      if (await FlutterSingleInstance().isFirstInstance()) {
        runApp(const LinuxApp());
      }
      break;
    case 'macos':
      debugPrint('Running on macOS');
      break;
    default:
      debugPrint('Unsupported platform');
  }
}
