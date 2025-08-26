import 'dart:typed_data';

import 'package:music_player_frontend/core/entities/abstract/abstract__named_entity.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_persistent_entity.dart';
import 'package:music_player_frontend/core/entities/abstract/mixin_collection.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Playlist extends PersistentEntity<Playlist>
    with AbstractCollection
    implements NamedEntity {
  @Id(assignable: true)
  int id = 0;

  @Unique()
  String _name = "Unknown playlist";

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  bool indestructible = false;
  bool visible = true;

  String nextAdded = "last";
  List<String> pathsInOrder = [];

  @Property(type: PropertyType.byteVector)
  Uint8List? coverArt;

  @Property(type: PropertyType.date) // milliseconds since epoch
  DateTime createdAt = DateTime.now();

  final _songs = ToMany<Song>();

  @override
  ToMany<Song> get songs => _songs;

  void save() {
    super.persist(this);
  }
}
