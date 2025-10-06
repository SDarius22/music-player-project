import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/artist_repo.dart';

class ArtistService {
  final ArtistRepository _artistRepository;

  ArtistService(this._artistRepository);

  Stream watchArtists() => _artistRepository.watchArtists();

  Artist getArtist(int artistId) {
    try {
      return _artistRepository.getArtist(artistId)!;
    } catch (e) {
      throw Exception("Artist with ID $artistId not found.");
    }
  }

  Artist getOrCreateArtist(String artistName) {
    Artist? existingArtist = _artistRepository.getArtistByName(artistName);
    if (existingArtist != null) {
      return existingArtist;
    }
    Artist newArtist = Artist();
    newArtist.name = artistName;
    return _artistRepository.saveArtist(newArtist);
  }

  Artist getArtistByName(String artistName) {
    try {
      return _artistRepository.getArtistByName(artistName)!;
    } catch (e) {
      throw Exception("Artist with name $artistName not found.");
    }
  }

  List<Artist> getArtists(String query, String sortField, bool flag) {
    return _artistRepository.getArtists(query, sortField, flag);
  }

  List<Artist> getAllArtists() {
    return _artistRepository.getAllArtists();
  }

  void updateArtist(Artist artist) {
    _artistRepository.updateArtist(artist);
  }
}
