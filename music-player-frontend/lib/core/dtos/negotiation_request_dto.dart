class NegotiationRequestDto {
  final String name;
  final String artistName;
  final String albumName;
  final String photoBase64;
  final int durationInSeconds;
  final int trackNumber;
  final int discNumber;
  final int year;
  final String fileHash;
  final List<String> hashes;

  NegotiationRequestDto({
    required this.name,
    required this.artistName,
    required this.albumName,
    required this.photoBase64,
    required this.durationInSeconds,
    required this.trackNumber,
    required this.discNumber,
    required this.year,
    required this.fileHash,
    required this.hashes,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'artistName': artistName,
    'albumName': albumName,
    'durationInSeconds': durationInSeconds,
    'trackNumber': trackNumber,
    'discNumber': discNumber,
    'releaseYear': year,
    'fileHash': fileHash,
    'hashes': hashes,
    'photo': photoBase64,
  };
}
