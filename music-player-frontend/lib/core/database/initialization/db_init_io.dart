import 'package:music_player_frontend/core/database/objectBox.dart';

Future<void> initializeDatabase() async {
  await ObjectBox.initialize();
}
