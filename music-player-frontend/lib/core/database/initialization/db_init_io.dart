import 'package:music_player_frontend/core/database/object_box_store.dart';

Future<void> initializeDatabase() async {
  await ObjectBox.initialize();
}
