import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/artist_repo.dart';

class ArtistService {
  final ArtistRepository _artistRepository;

  ArtistService(this._artistRepository);

  Stream watchArtists() => _artistRepository.watchArtists();

  Artist addArtist(String name) {
    Artist artist = Artist();
    artist.name = name;
    return _artistRepository.saveArtist(artist);
  }

  Artist? getArtist(int artistId) {
    return _artistRepository.getArtist(artistId);
  }

  List<Artist> getArtists(String query, String sortField, bool flag) {
    return _artistRepository.getArtists(query, sortField, flag);
  }

  List<Artist> getAllArtists() {
    return _artistRepository.getAllArtists();
  }

  void updateArtist(Artist artist) {
    _artistRepository.saveArtist(artist);
  }

  void deleteArtist(Artist artist) {
    _artistRepository.deleteArtist(artist);
  }
}