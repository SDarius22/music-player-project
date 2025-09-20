import 'package:music_player_frontend/core/entities/abstract/abstract_named_entity.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_persistent_entity.dart';
import 'package:music_player_frontend/core/entities/abstract/mixin_collection.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Artist extends PersistentEntity<Artist>
    with AbstractCollection
    implements NamedEntity {
  @Id()
  int id = 0;

  @Unique()
  String _name = "Unknown artist";

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  @Backlink('artist')
  final _songs = ToMany<Song>();

  @override
  ToMany<Song> get songs => _songs;

  void save() {
    super.persist(this);
  }

  @override
  String toString() {
    return name;
  }
}
