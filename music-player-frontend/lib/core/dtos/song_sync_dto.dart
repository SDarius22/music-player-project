class SongSyncDto {
  final int songId;
  final int playCountDelta;
  final bool? likedByUser;
  final bool isDeleted;
  final DateTime? lastPlayed;
  final DateTime? addedAt;

  SongSyncDto({
    required this.songId,
    this.playCountDelta = 0,
    this.likedByUser,
    this.isDeleted = false,
    this.lastPlayed,
    this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'playCountDelta': playCountDelta,
    'likedByUser': likedByUser,
    'isDeleted': isDeleted,
    'lastPlayed': lastPlayed?.toIso8601String(),
    'addedAt': addedAt?.toIso8601String(),
  };

  factory SongSyncDto.fromJson(Map<String, dynamic> json) {
    return SongSyncDto(
      songId: json['songId'],
      playCountDelta: 0,
      likedByUser: json['likedByUser'],
      isDeleted: json['isDeleted'] ?? false,
      lastPlayed:
          json['lastPlayed'] != null
              ? DateTime.parse(json['lastPlayed'])
              : null,
      addedAt: json['addedAt'] != null ? DateTime.parse(json['addedAt']) : null,
    );
  }
}
