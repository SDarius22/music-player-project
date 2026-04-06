class ArtistDto {
  final String hash;
  final String name;

  ArtistDto({required this.hash, required this.name});

  factory ArtistDto.fromJson(Map<String, dynamic> json) {
    return ArtistDto(
      hash: json['hash'] as String,
      name: json['name'] as String,
    );
  }
}
