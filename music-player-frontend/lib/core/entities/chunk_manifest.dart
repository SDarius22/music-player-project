class ChunkManifest {
  final int songId;
  final int chunkSize;
  final int totalChunks;
  final int totalBytes;
  final List<String> hashes;

  ChunkManifest({
    required this.songId,
    required this.chunkSize,
    required this.totalChunks,
    required this.totalBytes,
    required this.hashes,
  });

  factory ChunkManifest.fromJson(Map<String, dynamic> json) {
    return ChunkManifest(
      songId: json['songId'],
      chunkSize: json['chunkSize'],
      totalChunks: json['totalChunks'],
      totalBytes: json['totalBytes'],
      hashes: List<String>.from(json['hashes']),
    );
  }
}
