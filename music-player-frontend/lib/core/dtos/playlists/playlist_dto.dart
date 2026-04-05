class PlaylistDto {
  final int id;
  final String name;
  final List<String> songFileHashes;
  final bool hasCover;

  PlaylistDto({
    required this.id,
    required this.name,
    required this.songFileHashes,
    required this.hasCover,
  });

  factory PlaylistDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        (json['songFileHashes'] as List<dynamic>? ?? const []);
    return PlaylistDto(
      id: (json['id'] as num? ?? 0).toInt(),
      name: json['name'] as String? ?? 'Unknown playlist',
      songFileHashes: raw.map((e) => e as String).toList(),
      hasCover: json['hasCover'] as bool? ?? false,
    );
  }
}
