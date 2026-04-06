import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';

class ArtistProvider with ChangeNotifier implements QueryableProvider {
  final ArtistService _artistService;

  ArtistProvider(this._artistService);

  @override
  Map<String, dynamic> get sortFields => const {'Name': null};

  String get defaultSortField => 'Name';

  Future<Artist?> fetchArtistDetails(String artistHash) async {
    return await _artistService.fetchArtistDetails(artistHash);
  }

  @override
  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) async {
    final result = await _artistService.getArtistsPage(
      query,
      sortField,
      ascending,
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
  Future<void> refresh() async {
    notifyListeners();
  }
}
