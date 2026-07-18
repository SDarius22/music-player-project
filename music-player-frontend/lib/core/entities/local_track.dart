import 'dart:typed_data';

import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';

@Entity()
class LocalTrack implements BaseEntity {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  String sourceKey;

  String sourceUri;

  @Index()
  String potentialIdentityKey;

  String? contentHash;
  String? resolvedSongHash;
  int? fileSize;

  @Property(type: PropertyType.dateNano)
  DateTime? modifiedAt;

  String name;
  String artistName;
  String albumName;
  int durationInSeconds;
  int trackNumber;
  int discNumber;
  int year;
  bool available;
  bool supportsRandomAccess;
  bool metadataLoaded;
  bool likedByUser = false;

  @Property(type: PropertyType.dateNano)
  DateTime? lastPlayed;
  int playCount = 0;

  LocalTrack({
    required this.sourceKey,
    required this.sourceUri,
    required this.potentialIdentityKey,
    this.name = 'Unknown Song',
    this.artistName = 'Unknown Artist',
    this.albumName = 'Unknown Album',
    this.durationInSeconds = 0,
    this.trackNumber = 0,
    this.discNumber = 0,
    this.year = 0,
    this.available = true,
    this.supportsRandomAccess = true,
    this.metadataLoaded = false,
  });

  String get playbackIdentity =>
      contentHash?.isNotEmpty == true ? contentHash! : 'local:$sourceKey';

  @override
  bool get isLocal => available;

  @override
  bool get isAvailableOffline => isLocal;

  @override
  bool get isAvailableToStream => resolvedSongHash?.isNotEmpty == true;

  @override
  String getName() => name;

  @override
  String getSecondaryText() => artistName;

  @override
  String getHash() => playbackIdentity;

  @override
  Uint8List? getCoverArt() => null;

  @override
  String getImageUrl() => '';
}
