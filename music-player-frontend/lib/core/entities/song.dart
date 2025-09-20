import 'dart:typed_data';

import 'package:music_player_frontend/core/entities/abstract/abstract_named_entity.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_persistent_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Song extends PersistentEntity<Song> implements NamedEntity {
  @Id()
  int id = 0;

  @Unique()
  String path = "";

  String lyricsPath = "";

  String _name = "Unknown song";

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  final artist = ToOne<Artist>();
  final album = ToOne<Album>();

  @Backlink()
  final playlists = ToMany<Playlist>();

  int duration = 0; // in seconds
  int trackNumber = 0;
  int discNumber = 0;
  int year = 0;

  // Addition user oriented properties
  @Property(type: PropertyType.date) // milliseconds since epoch
  DateTime? lastPlayed;
  int playCount = 0;
  bool liked = false;
  bool fullyLoaded = false;

  @Transient()
  bool existsExternally = false;

  @Transient()
  Uint8List? image;

  void save() {
    super.persist(this);
  }

  @override
  bool operator ==(Object other) =>
      other is Song && other.runtimeType == runtimeType && other.path == path;

  @override
  int get hashCode => path.hashCode;

  void fromJson(Map<String, dynamic> json) {
    path = json['path'] ?? "";
    lyricsPath = json['lyricsPath'] ?? "";
    name = json['title'] ?? "Unknown Song";
    duration = json['duration'] ?? 0;
    trackNumber = json['trackNumber'] ?? 0;
    discNumber = json['discNumber'] ?? 0;
    year = json['year'] ?? 0;
    try {
      image = json['image'];
    } catch (e) {
      image = null;
    }
  }
}
