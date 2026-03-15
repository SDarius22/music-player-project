class ChunkDeliveryStats {
  final int songId;
  final String songName;
  final int p2pChunks;
  final int serverChunks;

  const ChunkDeliveryStats({
    required this.songId,
    required this.songName,
    required this.p2pChunks,
    required this.serverChunks,
  });

  int get totalChunks => p2pChunks + serverChunks;

  double get p2pPercentage =>
      totalChunks > 0 ? (p2pChunks / totalChunks * 100) : 0.0;

  @override
  String toString() =>
      'ChunkDeliveryStats(song=$songName, p2p=$p2pChunks, server=$serverChunks, '
      'total=$totalChunks, p2p%=${p2pPercentage.toStringAsFixed(1)}%)';
}
