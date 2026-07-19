import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/features/library/presentation/providers/queryable_provider.dart';
import 'package:music_player_frontend/core/services/album_service.dart';

class AlbumProvider with ChangeNotifier implements QueryableProvider {
  final AlbumService _albumService;

  AlbumProvider(this._albumService);

  @override
  Map<String, dynamic> get sortFields => const {'Name': null};

  String get defaultSortField => 'Name';

  @override
  Future<Album?> fetchEntity(BaseEntity album) async {
    if (album is Album &&
        album.hash.startsWith('local-album:') &&
        album.remoteSourceHashes.isNotEmpty) {
      return album;
    }
    return await _albumService.fetchAlbumDetails(album.getHash());
  }

  @override
  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    bool localOnly,
    int page,
    int size, {
    bool streamOnly = false,
  }) async {
    final result = await _albumService.getAlbumsPage(
      query,
      sortField,
      ascending,
      localOnly,
      page,
      size,
      streamOnly: streamOnly,
    );
    return PageResult(
      content: result.content,
      totalPages: result.totalPages,
      page: result.page,
    );
  }

  @override
  Future<PageResult<Song>> getSongsPage(
    String hash, {
    bool localOnly = false,
    int page = 0,
    int size = 10,
  }) async {
    return await _albumService.getAlbumSongsPage(
      hash,
      localOnly: localOnly,
      page: page,
      size: size,
    );
  }

  @override
  Future<void> refresh() async {
    notifyListeners();
  }
}
