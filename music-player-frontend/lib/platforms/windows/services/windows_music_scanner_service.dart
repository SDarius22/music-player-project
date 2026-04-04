import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class WindowsMusicScannerService implements AbstractMusicScannerService {
  final SongService _songService;
  final ArtistService _artistService;
  final AlbumService _albumService;
  final AbstractFileService _fileService;
  final SettingsService _settingsService;

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  bool _isScanning = false;

  WindowsMusicScannerService(
    this._songService,
    this._artistService,
    this._albumService,
    this._fileService,
    this._settingsService,
  );

  AppSettings get _currentSettings => _settingsService.getAppSettings();

  @override
  Stream<double> get progressStream => _progressController.stream;

  @override
  Future<void> performQuickScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _progressController.add(0.0);

    List<String> musicDirectories = _currentSettings.songPlaces;
    final files = await _fileService.getAudioFiles(musicDirectories);

    if (files.isEmpty) {
      _isScanning = false;
      _progressController.add(1.0);
      Future.delayed(const Duration(seconds: 1), () {
        _progressController.add(2.0);
      });
      return;
    }

    int processedCount = 0;
    List<Song> songsToUpdate = [];

    for (int i = 0; i < files.length; i++) {
      await Future.delayed(const Duration(milliseconds: 8));

      final file = files[i];
      final existing = await _songService.getSong(file.path);

      if (existing == null) {
        try {
          final metadata = await _fileService.retrieveSong(
            file.path,
            withImage: true,
          );

          var artist = _artistService.getOrCreateArtist(
            metadata['artist'] ?? 'Unknown Artist',
          );
          var album = _albumService.getOrCreateAlbum(
            metadata['album'] ?? 'Unknown Album',
            artist.id,
            image: metadata['image'],
          );

          final song =
              Song()
                ..path = file.path
                ..name =
                    metadata['title'] ?? _getFileNameWithoutExtension(file.path)
                ..durationInSeconds = metadata['duration'] ?? 0
                ..trackNumber = metadata['trackNumber'] ?? 0
                ..discNumber = metadata['discNumber'] ?? 0
                ..year = metadata['year'] ?? 0
                ..fullyLoaded = true
                ..artist.target = artist
                ..album.target = album;

          songsToUpdate.add(song);

          album.songs.add(song);
          _albumService.updateAlbum(album);

          artist.songs.add(song);
          artist.albums.add(album);
          _artistService.updateArtist(artist);
        } catch (e) {
          debugPrint(e.toString());

          var artist = _artistService.getOrCreateArtist('Unknown Artist');
          var album = _albumService.getOrCreateAlbum(
            'Unknown Album',
            artist.id,
          );

          final song =
              Song()
                ..path = file.path
                ..name = _getFileNameWithoutExtension(file.path)
                ..fullyLoaded = true
                ..requiresSync = true
                ..artist.target = artist
                ..album.target = album;

          songsToUpdate.add(song);
        }
      }

      processedCount++;

      if (songsToUpdate.length >= 100) {
        _songService.updateSongsBatch(songsToUpdate);
        songsToUpdate.clear();

        double progress = processedCount / files.length;
        _progressController.add(progress);
      }
    }

    if (songsToUpdate.isNotEmpty) {
      _songService.updateSongsBatch(songsToUpdate);
      double progress = processedCount / files.length;
      _progressController.add(progress);
    }

    _isScanning = false;
    _progressController.add(1.0);

    Future.delayed(const Duration(seconds: 1), () {
      _progressController.add(2.0);
    });
  }

  String _getFileNameWithoutExtension(String path) {
    return path.replaceAll("\\", "/").split("/").last.split('.').first;
  }
}
