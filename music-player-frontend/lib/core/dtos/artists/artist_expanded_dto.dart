class ArtistExpandedDto {
  final int id;
  final String name;
  final List<String> songFileHashes;

  ArtistExpandedDto({
    required this.id,
    required this.name,
    required this.songFileHashes,
  });

  factory ArtistExpandedDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        (json['songFileHashes'] as List<dynamic>? ?? const []);
    return ArtistExpandedDto(
      id: (json['id'] as num? ?? 0).toInt(),
      name: json['name'] as String? ?? 'Unknown artist',
      songFileHashes: raw.map((e) => e as String).toList(),
    );
  }
}
