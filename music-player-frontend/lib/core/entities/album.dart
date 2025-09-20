import 'dart:typed_data';

import 'package:music_player_frontend/core/entities/abstract/abstract_named_entity.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_persistent_entity.dart';
import 'package:music_player_frontend/core/entities/abstract/mixin_collection.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Album extends PersistentEntity<Album>
    with AbstractCollection
    implements NamedEntity {
  @Id()
  int id = 0;

  String _name = "Unknown album";

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  @Backlink('album')
  final _songs = ToMany<Song>();

  @override
  ToMany<Song> get songs => _songs;

  @Property(type: PropertyType.byteVector)
  Uint8List? coverArt;

  void save() {
    super.persist(this);
  }

  @override
  String toString() {
    return name;
  }
}
