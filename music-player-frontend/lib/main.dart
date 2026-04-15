import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fullscreen/flutter_fullscreen.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/database/initialization/db_init.dart';
import 'package:music_player_frontend/core/logging/app_logger.dart';
import 'package:music_player_frontend/local_libs/just_audio_media_kit/just_audio_media_kit.dart';
import 'package:music_player_frontend/platforms/android/android_app.dart';
import 'package:music_player_frontend/platforms/linux/linux_app.dart';
import 'package:music_player_frontend/platforms/macos/macos_app.dart';
import 'package:music_player_frontend/platforms/windows/windows_app.dart';
import 'package:permission_handler/permission_handler.dart';

final _logger = Logger('main');

Future<void> main() async {
  configureAppLogging();
  await runWithLoggingZone(() async {
    WidgetsFlutterBinding.ensureInitialized();

    JustAudioMediaKit.protocolWhitelist = ["http", "https", "file"];
    JustAudioMediaKit.title = 'Music Player';
    JustAudioMediaKit.ensureInitialized(linux: true, windows: true, macOS: true);

    await runOnTargetPlatform();
  });
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
      _logger.info('Running on Android');
      runApp(const AndroidApp());
      break;
    case 'windows':
      _logger.info('Running on Windows');
      if (await FlutterSingleInstance().isFirstInstance()) {
        await initializeDatabase();
        appWindow.minSize = const Size(250, 250);
        appWindow.maximize();
        runApp(const WindowsApp());
      }
      break;
    case 'linux':
      _logger.info('Running on Linux');
      if (await FlutterSingleInstance().isFirstInstance()) {
        await initializeDatabase();
        appWindow.minSize = const Size(250, 250);
        appWindow.maximize();
        runApp(const LinuxApp());
      }
      break;
    case 'macos':
      _logger.info('Running on macOS');
      if (await FlutterSingleInstance().isFirstInstance()) {
        await initializeDatabase();
        await FullScreen.ensureInitialized();
        appWindow.minSize = const Size(250, 250);
        appWindow.maximize();
        runApp(const MacosApplication());
      }
      break;
    default:
      _logger.warning('Unsupported platform');
  }
}
