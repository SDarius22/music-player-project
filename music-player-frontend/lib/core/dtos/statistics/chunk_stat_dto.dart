class ChunkStatDto {
  final int? id;
  final DateTime? timestamp;
  final int? userId;
  final String songFileHash;
  final String songName;
  final int localChunks;
  final int localCachedChunks;
  final int p2pChunks;
  final int serverChunks;
  final int? totalChunks;
  final double? p2pPercentage;

  ChunkStatDto({
    this.id,
    this.timestamp,
    this.userId,
    required this.songFileHash,
    required this.songName,
    this.localChunks = 0,
    this.localCachedChunks = 0,
    this.p2pChunks = 0,
    this.serverChunks = 0,
    this.totalChunks,
    this.p2pPercentage,
  });

  Map<String, dynamic> toJson() => {
    'songFileHash': songFileHash,
    'songName': songName,
    'localChunks': localChunks,
    'localCachedChunks': localCachedChunks,
    'p2pChunks': p2pChunks,
    'serverChunks': serverChunks,
  };

  factory ChunkStatDto.fromJson(Map<String, dynamic> json) {
    return ChunkStatDto(
      id: (json['id'] as num?)?.toInt(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      userId: (json['userId'] as num?)?.toInt(),
      songFileHash: json['songFileHash'] as String,
      songName: json['songName'] as String,
      localChunks: (json['localChunks'] as num? ?? 0).toInt(),
      localCachedChunks: (json['localCachedChunks'] as num? ?? 0).toInt(),
      p2pChunks: (json['p2pChunks'] as num? ?? 0).toInt(),
      serverChunks: (json['serverChunks'] as num? ?? 0).toInt(),
      totalChunks: (json['totalChunks'] as num?)?.toInt(),
      p2pPercentage: (json['p2pPercentage'] as num?)?.toDouble(),
    );
  }
}
