class ChunkManifestDto {
  final String fileHash;
  final int totalChunks;
  final int chunkSize;
  final int totalBytes;
  final List<String> hashes;

  ChunkManifestDto.fromJson(Map<String, dynamic> json)
    : fileHash = json['fileHash'] as String,
      totalChunks = json['totalChunks'],
      chunkSize = json['chunkSize'],
      totalBytes = json['totalBytes'],
      hashes = List<String>.from(json['hashes']);
}
