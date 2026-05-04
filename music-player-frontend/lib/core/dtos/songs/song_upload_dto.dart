class SongUploadDto {
  final String name;
  final String artistName;
  final String albumName;
  final String? fileHash;
  final int? durationInSeconds;
  final int? trackNumber;
  final int? discNumber;
  final int? releaseYear;
  final String? photo;

  SongUploadDto({
    required this.name,
    required this.artistName,
    required this.albumName,
    this.fileHash,
    this.durationInSeconds,
    this.trackNumber,
    this.discNumber,
    this.releaseYear,
    this.photo,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'artistName': artistName,
      'albumName': albumName,
      'fileHash': fileHash,
      'durationInSeconds': durationInSeconds,
      'trackNumber': trackNumber,
      'discNumber': discNumber,
      'releaseYear': releaseYear,
      'photo': photo,
    };
  }
}
