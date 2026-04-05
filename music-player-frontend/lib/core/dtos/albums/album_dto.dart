class AlbumDto {
  final int id;
  final String name;

  AlbumDto({required this.id, required this.name});

  factory AlbumDto.fromJson(Map<String, dynamic> json) {
    return AlbumDto(
      id: (json['id'] as num? ?? 0).toInt(),
      name: json['name'] as String? ?? 'Unknown album',
    );
  }
}
