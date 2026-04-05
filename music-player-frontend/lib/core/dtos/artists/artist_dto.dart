class ArtistDto {
  final int id;
  final String name;

  ArtistDto({required this.id, required this.name});

  factory ArtistDto.fromJson(Map<String, dynamic> json) {
    return ArtistDto(
      id: (json['id'] as num? ?? 0).toInt(),
      name: json['name'] as String? ?? 'Unknown artist',
    );
  }
}
