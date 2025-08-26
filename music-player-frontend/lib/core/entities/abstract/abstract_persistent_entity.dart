import 'package:music_player_frontend/core/database/objectBox.dart';

abstract class PersistentEntity<T> {
  void persist(T entity) {
    final box = ObjectBox.store.box<T>();
    box.put(entity);
  }
}
