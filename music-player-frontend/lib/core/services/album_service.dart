import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/album_repo.dart';

class AlbumService {
  final AlbumRepository _albumRepo;

  AlbumService(this._albumRepo);

  Stream watchAlbums() => _albumRepo.watchAllAlbums();

  void addAlbum(String name) {
    if (name.isEmpty) {
      throw ArgumentError("Album name cannot be empty");
    }
    Album album = Album();
    album.name = name;

    try{
      _albumRepo.addAlbum(album);
    } catch (e) {
      debugPrint("Error adding album: $e");
    }
  }

  Album? getAlbum(String name) {
    if (name.isEmpty) {
      throw ArgumentError("Album name cannot be empty");
    }
    try {
      return  _albumRepo.getAlbum(name);
    } catch (e) {
      debugPrint("Error fetching album: $e");
      return null;
    }
  }

  List<Album> getAlbums(String query, String sortField, bool flag) {
    try {
      return _albumRepo.getAlbums(query, sortField, flag);
    } catch (e) {
      debugPrint("Error fetching albums: $e");
      return [];
    }
  }

  List<Album> getAllAlbums() {
    try {
      return _albumRepo.getAllAlbums();
    } catch (e) {
      debugPrint("Error fetching all albums: $e");
      return [];
    }
  }

  void deleteAlbum(Album album) {
    if (album.id == 0) {
      throw ArgumentError("Album ID cannot be zero");
    }
    try {
       _albumRepo.deleteAlbum(album);
    } catch (e) {
      debugPrint("Error deleting album: $e");
    }
  }

  void updateAlbum(Album album) {
    if (album.id == 0) {
      throw ArgumentError("Album ID cannot be zero");
    }
    try {
       _albumRepo.updateAlbum(album);
    } catch (e) {
      debugPrint("Error updating album: $e");
    }
  }

  void addSongToAlbum(Song song, String albumName) {
    Album? album = _albumRepo.getAlbum(albumName);
    if (album == null) {
      album = Album();
      album.name = albumName;
      album.songs.add(song);
      album.duration += song.duration;
      _albumRepo.addAlbum(album);
    }
    else {
      album.songs.add(song);
      album.duration += song.duration;
      _albumRepo.updateAlbum(album);
    }
  }
}