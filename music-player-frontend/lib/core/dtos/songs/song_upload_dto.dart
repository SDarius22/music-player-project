class SongUploadDto {
  final String name;
  final String artistName;
  final String albumName;
  final String fileHash;
  final int durationSeconds;
  final int trackNumber;
  final int discNumber;
  final int releaseYear;
  final String coverImageBase64;

  SongUploadDto({
    required this.name,
    required this.artistName,
    required this.albumName,
    required this.fileHash,
    required this.durationSeconds,
    required this.trackNumber,
    required this.discNumber,
    required this.releaseYear,
    required this.coverImageBase64,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'artistName': artistName,
      'albumName': albumName,
      'fileHash': fileHash,
      'durationSeconds': durationSeconds,
      'trackNumber': trackNumber,
      'discNumber': discNumber,
      'releaseYear': releaseYear,
      'coverImage': coverImageBase64,
    };
  }
}
