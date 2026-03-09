class NegotiationRequestDto {
  final String name;
  final String artistName;
  final String albumName;
  final int durationInSeconds;
  final int trackNumber;
  final int year;
  final List<String> hashes;

  NegotiationRequestDto({
    required this.name,
    required this.artistName,
    required this.albumName,
    required this.durationInSeconds,
    required this.trackNumber,
    required this.year,
    required this.hashes,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'artistName': artistName,
    'albumName': albumName,
    'durationInSeconds': durationInSeconds,
    'trackNumber': trackNumber,
    'releaseYear': year,
    'hashes': hashes,
  };
}
