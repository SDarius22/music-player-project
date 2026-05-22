import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';

@Entity()
class ChunkStat {
  @Id()
  int id = 0;

  @Property(type: PropertyType.dateNano)
  DateTime timestamp;

  @Index()
  String songFileHash;
  String songName;

  int? userId;

  int localChunks;
  int localCachedChunks;
  int p2pChunks;
  int serverChunks;

  ChunkStat({
    required this.songFileHash,
    required this.songName,
    DateTime? timestamp,
    this.userId,
    this.localChunks = 0,
    this.localCachedChunks = 0,
    this.p2pChunks = 0,
    this.serverChunks = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  int get totalChunks =>
      localChunks + localCachedChunks + p2pChunks + serverChunks;

  double get p2pPercentage =>
      totalChunks > 0 ? (p2pChunks / totalChunks * 100) : 0.0;

  bool get isLocalFilePlayback =>
      localChunks > 0 &&
      p2pChunks == 0 &&
      serverChunks == 0 &&
      localCachedChunks == 0;

  factory ChunkStat.fromJson(Map<String, dynamic> json) {
    return ChunkStat(
      timestamp:
          json['timestamp'] != null
              ? DateTime.parse(json['timestamp'] as String)
              : DateTime.now(),
      userId: json['userId'] as int?,
      songFileHash: json['songFileHash'] as String? ?? '',
      songName: json['songName'] as String? ?? '',
      localChunks: (json['localChunks'] as num?)?.toInt() ?? 0,
      localCachedChunks: (json['localCachedChunks'] as num?)?.toInt() ?? 0,
      p2pChunks: (json['p2pChunks'] as num?)?.toInt() ?? 0,
      serverChunks: (json['serverChunks'] as num?)?.toInt() ?? 0,
    )..id = (json['id'] as num?)?.toInt() ?? 0;
  }

  Map<String, dynamic> toSubmissionJson() => {
    'songFileHash': songFileHash,
    'songName': songName,
    'localChunks': localChunks,
    'localCachedChunks': localCachedChunks,
    'p2pChunks': p2pChunks,
    'serverChunks': serverChunks,
  };

  @override
  String toString() =>
      'ChunkStat(song=$songName, local=$localChunks, cached=$localCachedChunks, '
      'p2p=$p2pChunks, server=$serverChunks, total=$totalChunks, '
      'p2p%=${p2pPercentage.toStringAsFixed(1)}%)';
}
