import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/artist_repo.dart';

class ArtistService {
  final ArtistRepository _artistRepo;

  ArtistService(this._artistRepo);

  Stream watchArtists() => _artistRepo.watchAllArtists();

  void addArtist(String name) async {
    if (name.isEmpty) {
      throw ArgumentError("Artist name cannot be empty");
    }
    // Check if the artist already exists
    final existingArtist =  _artistRepo.getArtist(name);
    if (existingArtist != null) {
      throw Exception("Artist with name '$name' already exists");
    }
    Artist newArtist = Artist();
    newArtist.name = name;
    try {
       _artistRepo.addArtist(newArtist);
    } catch (e) {
      debugPrint("Error adding artist: $e");
    }
  }

  Artist? getArtist(String name) {
    if (name.isEmpty) {
      throw ArgumentError("Artist name cannot be empty");
    }
    try{
      return  _artistRepo.getArtist(name);
    } catch (e) {
      debugPrint("Error fetching artist: $e");
      return null;
    }
  }

  List<Artist> getArtists(String query, String sortField, bool flag) {
    try{
      return  _artistRepo.getArtists(query, sortField, flag);
    }
    catch (e) {
      debugPrint("Error fetching artists: $e");
      return [];
    }
  }

  List<Artist> getAllArtists() {
    try {
      return _artistRepo.getAllArtists();
    } catch (e) {
      debugPrint("Error fetching all artists: $e");
      return [];
    }
  }

  void updateArtist(Artist artist) {
    if (artist.name.isEmpty) {
      throw ArgumentError("Artist name cannot be empty");
    }
    try {
       _artistRepo.updateArtist(artist);
    } catch (e) {
      debugPrint("Error updating artist: $e");
    }
  }

  void deleteArtist(Artist artist) {
    if (artist.id <= 0) {
      throw ArgumentError("Invalid artist ID");
    }
    try {
       _artistRepo.deleteArtist(artist);
    } catch (e) {
      debugPrint("Error deleting artist: $e");
    }
  }

  void addSongToArtist(Song song, String artistName) {
    Artist? artist = _artistRepo.getArtist(artistName);
    if (artist == null) {
      artist = Artist();
      artist.name = artistName;
      artist.songs.add(song);
      artist.duration += song.duration;
      _artistRepo.addArtist(artist);
    }
    else {
      artist.songs.add(song);
      artist.duration += song.duration;
      _artistRepo.updateArtist(artist);
    }
  }
}