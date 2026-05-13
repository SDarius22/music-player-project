import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';

class ArtistProvider with ChangeNotifier implements QueryableProvider {
  final ArtistService _artistService;

  ArtistProvider(this._artistService);

  @override
  Map<String, dynamic> get sortFields => const {'Name': null};

  String get defaultSortField => 'Name';

  @override
  Future<Artist?> fetchEntity(BaseEntity artist) async {
    return await _artistService.fetchArtistDetails(artist.getHash());
  }

  @override
  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    bool localOnly,
    int page,
    int size,
  ) async {
    final result = await _artistService.getArtistsPage(
      query,
      sortField,
      ascending,
      localOnly,
      page,
      size,
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
    return _artistService.getArtistSongsPage(
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
