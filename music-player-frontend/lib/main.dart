import 'dart:io';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/platforms/linux/ui/linux_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  switch (Platform.operatingSystem) {
    case 'windows':
      debugPrint('Running on Windows');
      break;
    case 'linux':
      debugPrint('Running on Linux');
      if(await FlutterSingleInstance().isFirstInstance()){
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