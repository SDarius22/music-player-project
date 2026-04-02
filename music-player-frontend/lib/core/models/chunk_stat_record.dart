class ChunkStatRecord {
  final int id;
  final DateTime timestamp;
  final int? userId;
  final int? songId;
  final String? songName;
  final int localChunks;
  final int localCachedChunks;
  final int p2pChunks;
  final int serverChunks;
  final int totalChunks;
  final double p2pPercentage;

  const ChunkStatRecord({
    required this.id,
    required this.timestamp,
    this.userId,
    this.songId,
    this.songName,
    this.localChunks = 0,
    this.localCachedChunks = 0,
    required this.p2pChunks,
    required this.serverChunks,
    required this.totalChunks,
    required this.p2pPercentage,
  });

  factory ChunkStatRecord.fromJson(Map<String, dynamic> json) {
    return ChunkStatRecord(
      id: json['id'] as int? ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      userId: json['userId'] as int?,
      songId: json['songId'] as int?,
      songName: json['songName'] as String?,
      localChunks: json['localChunks'] as int? ?? 0,
      localCachedChunks: json['localCachedChunks'] as int? ?? 0,
      p2pChunks: json['p2pChunks'] as int? ?? 0,
      serverChunks: json['serverChunks'] as int? ?? 0,
      totalChunks: json['totalChunks'] as int? ?? 0,
      p2pPercentage: (json['p2pPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
