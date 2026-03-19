import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/album_service.dart';

class AlbumProvider with ChangeNotifier implements QueryableProvider {
  final AlbumService _albumService;

  AlbumProvider(this._albumService);

  @override
  Map<String, dynamic> get sortFields => const {'Name': null};

  String get defaultSortField => 'Name';

  @override
  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) async {
    final dto = await _albumService.getAlbumsPage(
      query,
      sortField,
      ascending,
      page,
      size,
    );
    return PageResult(
      content: dto.content,
      totalPages: dto.totalPages,
      page: dto.page,
    );
  }

  @override
  Future<void> refresh() async {
    notifyListeners();
  }

  Album getAlbum(int albumId) => _albumService.getAlbum(albumId);

  List<Album> getAllAlbums() => _albumService.getAllAlbums();
}
