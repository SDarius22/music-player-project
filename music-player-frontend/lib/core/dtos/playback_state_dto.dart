class PlaybackStateDto {
  final List<int> queueSongIds;
  final int? currentSongId;
  final int positionMs;
  final bool shuffle;
  final bool repeat;

  const PlaybackStateDto({
    required this.queueSongIds,
    this.currentSongId,
    this.positionMs = 0,
    this.shuffle = false,
    this.repeat = false,
  });

  factory PlaybackStateDto.fromJson(Map<String, dynamic> json) {
    return PlaybackStateDto(
      queueSongIds: (json['queueSongIds'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      currentSongId: json['currentSongId'] != null
          ? (json['currentSongId'] as num).toInt()
          : null,
      positionMs: (json['positionMs'] as num? ?? 0).toInt(),
      shuffle: json['shuffle'] as bool? ?? false,
      repeat: json['repeat'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'queueSongIds': queueSongIds,
    'currentSongId': currentSongId,
    'positionMs': positionMs,
    'shuffle': shuffle,
    'repeat': repeat,
  };
}
