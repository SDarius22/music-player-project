class SongSyncDto {
  final String fileHash;
  final int playCountDelta;
  final bool? likedByUser;
  final bool isDeleted;
  final DateTime? lastPlayed;
  final DateTime? addedAt;
  final int? totalPlayDurationSeconds;

  SongSyncDto({
    required this.fileHash,
    this.playCountDelta = 0,
    this.likedByUser,
    this.isDeleted = false,
    this.lastPlayed,
    this.addedAt,
    this.totalPlayDurationSeconds,
  });

  Map<String, dynamic> toJson() => {
    'fileHash': fileHash,
    'playCountDelta': playCountDelta,
    'likedByUser': likedByUser,
    'isDeleted': isDeleted,
    'lastPlayed': lastPlayed?.toIso8601String(),
    'addedAt': addedAt?.toIso8601String(),
    'totalPlayDurationSeconds': totalPlayDurationSeconds,
  };

  factory SongSyncDto.fromJson(Map<String, dynamic> json) {
    return SongSyncDto(
      fileHash: json['fileHash'] as String,
      playCountDelta: 0,
      likedByUser: json['likedByUser'],
      isDeleted: json['isDeleted'] ?? false,
      lastPlayed:
          json['lastPlayed'] != null
              ? DateTime.parse(json['lastPlayed'])
              : null,
      addedAt: json['addedAt'] != null ? DateTime.parse(json['addedAt']) : null,
      totalPlayDurationSeconds: json['totalPlayDurationSeconds'] as int?,
    );
  }
}
