class PlaylistExpandedDto {
  final int id;
  final String name;
  final bool indestructible;
  final List<String> songFileHashes;
  final int durationSeconds;

  PlaylistExpandedDto({
    required this.id,
    required this.name,
    required this.songFileHashes,
    required this.indestructible,
    required this.durationSeconds,
  });

  factory PlaylistExpandedDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['songFileHashes'] as List<dynamic>);
    return PlaylistExpandedDto(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      songFileHashes: raw.map((e) => e as String).toList(),
      durationSeconds: (json['durationInSeconds'] as num? ?? 0).toInt(),
      indestructible: json['indestructible'] as bool? ?? false,
    );
  }
}
