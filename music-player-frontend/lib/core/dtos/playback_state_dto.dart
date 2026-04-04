class PlaybackStateDto {
  final List<String> queueFileHashes;
  final String? currentFileHash;
  final int positionMs;
  final bool shuffle;
  final bool repeat;

  const PlaybackStateDto({
    required this.queueFileHashes,
    this.currentFileHash,
    this.positionMs = 0,
    this.shuffle = false,
    this.repeat = false,
  });

  factory PlaybackStateDto.fromJson(Map<String, dynamic> json) {
    return PlaybackStateDto(
      queueFileHashes: (json['queueFileHashes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      currentFileHash: json['currentFileHash'] as String?,
      positionMs: (json['positionMs'] as num? ?? 0).toInt(),
      shuffle: json['shuffle'] as bool? ?? false,
      repeat: json['repeat'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'queueFileHashes': queueFileHashes,
    'currentFileHash': currentFileHash,
    'positionMs': positionMs,
    'shuffle': shuffle,
    'repeat': repeat,
  };
}
