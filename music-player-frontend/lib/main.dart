import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fullscreen/flutter_fullscreen.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:music_player_frontend/core/database/initialization/db_init.dart';
import 'package:music_player_frontend/local_libs/just_audio_media_kit/just_audio_media_kit.dart';
import 'package:music_player_frontend/platforms/android/ui/android_app.dart';
import 'package:music_player_frontend/platforms/linux/ui/linux_app.dart';
import 'package:music_player_frontend/platforms/macos/ui/macos_app.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  JustAudioMediaKit.protocolWhitelist = ["http", "https", "file"];
  JustAudioMediaKit.title = 'Music Player';
  JustAudioMediaKit.ensureInitialized(linux: true, windows: true);

  await runOnTargetPlatform();
}

Future<void> runOnTargetPlatform() async {
  switch (Platform.operatingSystem) {
    case 'android':
      await [
        Permission.mediaLibrary,
        Permission.audio,
        Permission.storage,
      ].request();
      await initializeDatabase();
      debugPrint('Running on Android');
      runApp(const AndroidApp());
      break;
    case 'windows':
      debugPrint('Running on Windows');
      break;
    case 'linux':
      debugPrint('Running on Linux');
      if (await FlutterSingleInstance().isFirstInstance()) {
        await initializeDatabase();
        appWindow.minSize = const Size(800, 600);
        appWindow.maximize();
        runApp(const LinuxApp());
      }
      break;
    case 'macos':
      debugPrint('Running on macOS');
      if (await FlutterSingleInstance().isFirstInstance()) {
        await initializeDatabase();
        await FullScreen.ensureInitialized();
        appWindow.minSize = const Size(800, 600);
        appWindow.maximize();
        runApp(const MacosApplication());
      }
      break;
    default:
      debugPrint('Unsupported platform');
  }
}
