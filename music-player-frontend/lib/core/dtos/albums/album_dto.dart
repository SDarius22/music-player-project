class AlbumDto {
  final String hash;
  final String name;

  AlbumDto({required this.hash, required this.name});

  factory AlbumDto.fromJson(Map<String, dynamic> json) {
    return AlbumDto(hash: json['hash'] as String, name: json['name'] as String);
  }
}
