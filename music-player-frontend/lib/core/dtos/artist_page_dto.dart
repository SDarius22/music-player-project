import 'package:music_player_frontend/core/entities/artist.dart';

class ArtistPageDto {
  final List<Artist> content;
  final int page;
  final int size;
  final int totalPages;
  final int totalElements;

  ArtistPageDto({
    required this.content,
    required this.page,
    required this.size,
    required this.totalPages,
    required this.totalElements,
  });

  factory ArtistPageDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['content'] as List<dynamic>? ?? const []);
    return ArtistPageDto(
      content: raw.map((e) => Artist.fromJson(e as Map<String, dynamic>)).toList(),
      page: (json['page'] as num? ?? 0).toInt(),
      size: (json['size'] as num? ?? raw.length).toInt(),
      totalPages: (json['totalPages'] as num? ?? 1).toInt(),
      totalElements: (json['totalElements'] as num? ?? raw.length).toInt(),
    );
  }
}
