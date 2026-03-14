import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class MacosMusicScannerService implements AbstractMusicScannerService {
  final SongService _songService;
  final ArtistService _artistService;
  final AlbumService _albumService;
  final AbstractFileService _fileService;
  final SettingsService _settingsService;

  MacosMusicScannerService(
    this._songService,
    this._artistService,
    this._albumService,
    this._fileService,
    this._settingsService,
  );

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  bool _isEnrichmentRunning = false;
  bool _isEnrichmentDone = false;

  @override
  Stream<double> get progressStream => _progressController.stream;

  AppSettings get _currentSettings => _settingsService.getAppSettings();

  @override
  Future<void> performQuickScan() async {
    List<String> musicDirectories = _currentSettings.songPlaces;
    debugPrint("Starting quick scan for directories: $musicDirectories");

    final files = await _fileService.getAudioFiles(musicDirectories);
    int addedCount = 0;

    for (final file in files) {
      final existing = await _songService.getSong(file.path);
      if (existing == null) {
        var artist = _artistService.getOrCreateArtist('Unknown Artist');
        var album = _albumService.getOrCreateAlbum('Unknown Album', artist.id);
        final song =
            Song()
              ..path = file.path
              ..name = _getFileNameWithoutExtension(file.path)
              ..artist.target = artist
              ..album.target = album
              ..fullyLoaded = false;

        album.songs.add(song);
        _albumService.updateAlbum(album);

        artist.songs.add(song);
        artist.albums.add(album);
        _artistService.updateArtist(artist);

        _songService.addSongEntity(song);
        addedCount++;
      }
    }

    debugPrint(
      "Quick scan complete: $addedCount new songs added (${files.length} total files found)",
    );

    _startBackgroundEnrichment();
  }

  void _startBackgroundEnrichment() async {
    if (_isEnrichmentRunning || _isEnrichmentDone) return;

    _isEnrichmentRunning = true;
    _progressController.add(0.0); // Signal start

    final songs =
        (await _songService.getAllSongs())
            .where((song) => !song.fullyLoaded)
            .toList();

    if (songs.isEmpty) {
      debugPrint("No songs need metadata enrichment");
      _isEnrichmentDone = true;
      _isEnrichmentRunning = false;
      _progressController.add(2.0); // Signal done (hidden state)
      return;
    }

    debugPrint("Enriching metadata for ${songs.length} songs in background...");

    int processedCount = 0;
    DateTime lastEmit = DateTime.now();
    const emitInterval = Duration(seconds: 2); // Faster UI updates

    List<Song> songsToUpdate = [];

    for (int i = 0; i < songs.length; i++) {
      if (i % 50 == 0) {
        await Future.delayed(const Duration(milliseconds: 1));
      }

      final song = songs[i];
      try {
        final metadata = await _fileService.retrieveSong(
          song.path,
          withImage: true,
        );

        song.fromJson(metadata);
        song.fullyLoaded = true;
        var artist = _artistService.getOrCreateArtist(
          metadata['artist'] ?? 'Unknown Artist',
        );
        var album = _albumService.getOrCreateAlbum(
          metadata['album'] ?? 'Unknown Album',
          artist.id,
          image: metadata['image'],
        );

        song.artist.targetId = artist.id;
        song.album.target = album;
        songsToUpdate.add(song);

        album.songs.add(song);
        _albumService.updateAlbum(album);

        artist.songs.add(song);
        artist.albums.add(album);
        _artistService.updateArtist(artist);

        processedCount++;
      } catch (e) {
        debugPrint('Error extracting metadata for ${song.path}: $e');
        song.fullyLoaded = true;
        songsToUpdate.add(song);
        processedCount++;
      }

      if (DateTime.now().difference(lastEmit) >= emitInterval) {
        if (songsToUpdate.isNotEmpty) {
          _songService.updateSongsBatch(songsToUpdate);
          songsToUpdate.clear();
        }

        double progress = processedCount / songs.length;
        _progressController.add(progress);
        lastEmit = DateTime.now();
      }
    }

    if (songsToUpdate.isNotEmpty) {
      _songService.updateSongsBatch(songsToUpdate);
    }

    _isEnrichmentDone = true;
    _isEnrichmentRunning = false;
    _progressController.add(1.0);

    Future.delayed(const Duration(seconds: 1), () {
      _progressController.add(2.0);
    });
  }

  String _getFileNameWithoutExtension(String path) {
    return path.replaceAll("\\", "/").split("/").last.split('.').first;
  }
}
