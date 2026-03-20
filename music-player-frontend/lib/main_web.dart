import 'package:flutter/widgets.dart';
import 'package:music_player_frontend/platforms/web/web_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WebApp());
}
