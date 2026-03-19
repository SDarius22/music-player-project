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

  @override
  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) async {
    final dto = await _artistService.getArtistsPage(
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

  Artist getArtist(int artistId) => _artistService.getArtist(artistId);

  List<Artist> getAllArtists() => _artistService.getAllArtists();
}
