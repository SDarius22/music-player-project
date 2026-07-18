import 'dart:typed_data';
import 'dart:ui';

import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';

@Entity()
class Song implements BaseEntity {
  @Id()
  int id = 0;

  bool fullyLoaded = false;

  @Index()
  @Unique()
  final String fileHash;

  @Transient()
  String? localSourceKey;

  @Transient()
  String? potentialIdentityKey;

  @Transient()
  List<String> potentialRemoteHashes = [];

  @Transient()
  List<String> localSourceUris = [];

  String? path;
  int? localFileSize;

  @Property(type: PropertyType.dateNano)
  DateTime? localFileModifiedAt;
  int manifestChunkSize = 0;
  int manifestTotalBytes = 0;
  List<String> chunkHashes = [];
  int cachedChunkCount = 0;
  bool fullyCached = false;
  String name = 'Unknown Song';
  int durationInSeconds = 0;
  int trackNumber = 0;
  int discNumber = 0;
  int year = 0;

  final ToOne<Artist> artist = ToOne<Artist>();
  final ToOne<Album> album = ToOne<Album>();

  @Property(type: PropertyType.dateNano)
  DateTime? lastPlayed;
  int playCount = 0;
  bool likedByUser = false;

  Song(this.fileHash);

  @override
  String getName() {
    return name;
  }

  @override
  String getSecondaryText() {
    return artist.target?.name ?? 'Unknown Artist';
  }

  @override
  String getHash() {
    if (fileHash.isNotEmpty) return fileHash;
    return 'local:${localSourceKey ?? path ?? id}';
  }

  @override
  bool get isLocal {
    return isPlayableOffline;
  }

  bool get hasLocalFile => path != null && path!.isNotEmpty;

  bool get hasCachedChunks => cachedChunkCount > 0;

  @Transient()
  int get expectedChunkCount => chunkHashes.length;

  @Transient()
  bool get hasManifest =>
      manifestChunkSize > 0 && manifestTotalBytes > 0 && chunkHashes.isNotEmpty;

  bool get isFullyCached => fullyCached;

  bool get isPlayableOffline => hasLocalFile || isFullyCached;

  @override
  bool get isAvailableOffline => isPlayableOffline;

  @override
  bool get isAvailableToStream =>
      potentialRemoteHashes.isNotEmpty ||
      (fileHash.isNotEmpty && localSourceKey == null);

  bool matchesLocalFileStat(int size, DateTime modifiedAt) {
    return localFileSize == size &&
        localFileModifiedAt?.microsecondsSinceEpoch ==
            modifiedAt.microsecondsSinceEpoch;
  }

  set isLocal(bool value) {
    // This setter is intentionally left blank. The isLocal property is derived from the presence of a valid path.
  }

  @override
  String getImageUrl() {
    return '/songs/$fileHash/cover';
  }

  @override
  Uint8List? getCoverArt() {
    if (album.target != null) {
      return album.target!.imageBytes;
    }
    if (artist.target != null) {
      return artist.target!.imageBytes;
    }
    return null;
  }

  List<Color> getColors() {
    if (album.target != null && album.target!.colors.isNotEmpty) {
      return album.target!.colors;
    }
    return [];
  }

  void updateFrom(Song other) {
    if (other.fileHash != fileHash) {
      throw ArgumentError(
        'Cannot update from a song with a different file hash',
      );
    }

    name = other.name;
    durationInSeconds = other.durationInSeconds;
    trackNumber = other.trackNumber;
    discNumber = other.discNumber;
    year = other.year;
    path = other.path;
    localFileSize = other.localFileSize;
    localFileModifiedAt = other.localFileModifiedAt;
    fullyLoaded = other.fullyLoaded;
    artist.target = other.artist.target;
    album.target = other.album.target;
  }

  @override
  bool operator ==(Object other) {
    if (other is! Song) return false;
    return getHash() == other.getHash();
  }

  @override
  int get hashCode => getHash().hashCode;

  @override
  String toString() {
    return 'Song{id: $id, fileHash: $fileHash, name: $name, artist: ${artist.target?.name}, album: ${album.target?.name}}';
  }
}
