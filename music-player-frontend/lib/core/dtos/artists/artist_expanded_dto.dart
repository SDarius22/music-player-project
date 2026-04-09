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
    final List<dynamic> raw = (json['songFileHashes'] as List<dynamic>);
    return ArtistExpandedDto(
      hash: json['hash'] as String,
      name: json['name'] as String,
      songFileHashes: raw.map((e) => e as String).toList(),
    );
  }
}
