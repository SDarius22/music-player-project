class ChunkManifestDto {
  final int songId;
  final int totalChunks;
  final int chunkSize;
  final int totalBytes;
  final List<String> hashes;

  ChunkManifestDto.fromJson(Map<String, dynamic> json)
    : songId = json['songId'],
      totalChunks = json['totalChunks'],
      chunkSize = json['chunkSize'],
      totalBytes = json['totalBytes'],
      hashes = List<String>.from(json['hashes']);
}
