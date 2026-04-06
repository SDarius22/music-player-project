class ArtistExpandedDto {
  final String hash;
  final String name;
  final List<String> songFileHashes;

  ArtistExpandedDto({
    required this.hash,
    required this.name,
    required this.songFileHashes,
  });

  factory ArtistExpandedDto.fromJson(Map<String, dynamic> json) {
    final List<String> raw = (json['songFileHashes'] as List<String>);
    return ArtistExpandedDto(
      hash: json['hash'] as String,
      name: json['name'] as String,
      songFileHashes: raw,
    );
  }
}
