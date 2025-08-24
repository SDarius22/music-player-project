import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/album_repo.dart';

class AlbumService {
  final AlbumRepository albumRepo;

  AlbumService(this.albumRepo);


  Future<Album?> getAlbum(String name) async {
    if (name.isEmpty) {
      throw ArgumentError("Album name cannot be empty");
    }
    try {
      return await albumRepo.getAlbum(name);
    } catch (e) {
      debugPrint("Error fetching album: $e");
      return null;
    }
  }

  Future<List<Album>> getAlbums(String query, bool flag) async {
    try {
      return await albumRepo.getAlbums(query, flag);
    } catch (e) {
      debugPrint("Error fetching albums: $e");
      return [];
    }
  }

  Future<List<Album>> getAllAlbums() async {
    try {
      return await albumRepo.getAllAlbums();
    } catch (e) {
      debugPrint("Error fetching all albums: $e");
      return [];
    }
  }
}