import 'package:music_player_frontend/core/dtos/playlists/playlist_dto.dart';

class PlaylistPageDto {
  final List<PlaylistDto> content;
  final int page;
  final int size;
  final int totalPages;
  final int totalElements;

  PlaylistPageDto({
    required this.content,
    required this.page,
    required this.size,
    required this.totalPages,
    required this.totalElements,
  });

  factory PlaylistPageDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['content'] as List<dynamic>);
    return PlaylistPageDto(
      content:
          raw
              .map((e) => PlaylistDto.fromJson(e as Map<String, dynamic>))
              .toList(),
      page: (json['page'] as num).toInt(),
      size: (json['size'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      totalElements: (json['totalElements'] as num).toInt(),
    );
  }
}
