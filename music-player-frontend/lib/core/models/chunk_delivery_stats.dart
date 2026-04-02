class ChunkDeliveryStats {
  final int songId;
  final String songName;
  final int localChunks;
  final int localCachedChunks;
  final int p2pChunks;
  final int serverChunks;

  const ChunkDeliveryStats({
    required this.songId,
    required this.songName,
    this.localChunks = 0,
    this.localCachedChunks = 0,
    this.p2pChunks = 0,
    this.serverChunks = 0,
  });

  int get totalChunks => localChunks + localCachedChunks + p2pChunks + serverChunks;

  double get p2pPercentage =>
      totalChunks > 0 ? (p2pChunks / totalChunks * 100) : 0.0;

  @override
  String toString() =>
      'ChunkDeliveryStats(song=$songName, local=$localChunks, cached=$localCachedChunks, '
      'p2p=$p2pChunks, server=$serverChunks, total=$totalChunks, '
      'p2p%=${p2pPercentage.toStringAsFixed(1)}%)';
}
