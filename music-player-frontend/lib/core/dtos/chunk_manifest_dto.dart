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

  Map<String, dynamic> toJson() => {
    'fileHash': fileHash,
    'totalChunks': totalChunks,
    'chunkSize': chunkSize,
    'totalBytes': totalBytes,
    'hashes': hashes,
  };

  bool isValidFor(String expectedFileHash) {
    const maxFileBytes = 16 * 1024 * 1024 * 1024;
    const maxChunkBytes = 8 * 1024 * 1024;
    const maxChunks = 1000000;
    final expectedChunks =
        chunkSize > 0 ? (totalBytes + chunkSize - 1) ~/ chunkSize : 0;
    return fileHash == expectedFileHash &&
        totalChunks > 0 &&
        totalChunks <= maxChunks &&
        chunkSize > 0 &&
        chunkSize <= maxChunkBytes &&
        totalBytes > 0 &&
        totalBytes <= maxFileBytes &&
        expectedChunks == totalChunks &&
        hashes.length == totalChunks &&
        hashes.every((hash) => RegExp(r'^[a-f0-9]{64}$').hasMatch(hash));
  }
}
