class PlaybackStateDto {
  final int positionSeconds;
  final bool shuffle;
  final bool repeat;
  final DateTime? updatedAt;

  const PlaybackStateDto({
    this.positionSeconds = 0,
    this.shuffle = false,
    this.repeat = false,
    this.updatedAt,
  });

  int get positionMs => positionSeconds * 1000;

  factory PlaybackStateDto.fromJson(Map<String, dynamic> json) {
    return PlaybackStateDto(
      positionSeconds:
          (json['positionSeconds'] as num?)?.toInt() ??
          ((json['positionMs'] as num? ?? 0).toInt() ~/ 1000),
      shuffle: json['shuffle'] as bool? ?? false,
      repeat: json['repeat'] as bool? ?? false,
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'positionSeconds': positionSeconds,
    'shuffle': shuffle,
    'repeat': repeat,
  };
}
