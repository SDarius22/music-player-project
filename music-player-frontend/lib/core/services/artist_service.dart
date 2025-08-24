import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/artist_repo.dart';

class ArtistService {
  final ArtistRepository artistRepo;

  ArtistService(this.artistRepo);


  Future<Artist?> getArtist(String name) async {
    if (name.isEmpty) {
      throw ArgumentError("Artist name cannot be empty");
    }
    try{
      return await artistRepo.getArtist(name);
    } catch (e) {
      debugPrint("Error fetching artist: $e");
      return null;
    }
  }

  Future<List<Artist>> getArtists(String query, bool flag) async {
    try{
      return await artistRepo.getArtists(query, flag);
    }
    catch (e) {
      debugPrint("Error fetching artists: $e");
      return [];
    }
  }

  Future<List<Artist>> getAllArtists() async {
    try {
      return await artistRepo.getAllArtists();
    } catch (e) {
      debugPrint("Error fetching all artists: $e");
      return [];
    }
  }
}