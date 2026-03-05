class ChunkManifest {
  final int songId;
  final int chunkSize;
  final int totalChunks;
  final List<String> hashes;

  ChunkManifest({
    required this.songId,
    required this.chunkSize,
    required this.totalChunks,
    required this.hashes,
  });

  factory ChunkManifest.fromJson(Map<String, dynamic> json) {
    return ChunkManifest(
      songId: json['songId'],
      chunkSize: json['chunkSize'],
      totalChunks: json['totalChunks'],
      hashes: List<String>.from(json['hashes']),
    );
  }
}
