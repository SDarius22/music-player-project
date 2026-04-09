class PlaylistDto {
  final int id;
  final String name;
  final List<String> songFileHashes;

  PlaylistDto({
    required this.id,
    required this.name,
    required this.songFileHashes,
  });

  factory PlaylistDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['songFileHashes'] as List<dynamic>);
    return PlaylistDto(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      songFileHashes: raw.map((e) => e as String).toList(),
    );
  }
}
