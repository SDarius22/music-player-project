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

class MusicScannerService implements AbstractMusicScannerService {
  final SongService _songService;
  final ArtistService _artistService;
  final AlbumService _albumService;
  final FileService _fileService;
  final SettingsService _settingsService;

  MusicScannerService(
    this._songService,
    this._artistService,
    this._albumService,
    this._fileService,
    this._settingsService,
  );

  bool _isEnrichmentDone = false;

  AppSettings get _currentSettings => _settingsService.getAppSettings();

  @override
  Future<void> performQuickScan() async {
    List<String> musicDirectories = _currentSettings.songPlaces;
    debugPrint("Starting quick scan for directories: $musicDirectories");

    final files = await _fileService.getAudioFiles(musicDirectories);
    int addedCount = 0;

    for (final file in files) {
      final existing = _songService.getSong(file.path);
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
  }

  @override
  Stream<double> enrichMetadata() async* {
    if (_isEnrichmentDone) {
      debugPrint("Metadata enrichment already completed");
      yield 2.0;
      return;
    }

    final songs =
        _songService.getAllSongs().where((song) => !song.fullyLoaded).toList();

    if (songs.isEmpty) {
      debugPrint("No songs need metadata enrichment");
      yield 2.0;
      return;
    }

    debugPrint("Enriching metadata for ${songs.length} songs...");

    int processedCount = 0;
    DateTime lastEmit = DateTime.now();
    const emitInterval = Duration(seconds: 10);

    List<Song> songsToUpdate = [];

    for (int i = 0; i < songs.length; i++) {
      if (i % 100 == 0) {
        await Future.delayed(const Duration(milliseconds: 250));
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
        debugPrint("Progress: $processedCount/${songs.length} songs enriched");
        yield processedCount / songs.length;
        _songService.updateSongsBatch(songsToUpdate);
        // songsToUpdate.forEach((s) {});
        songsToUpdate.clear();
        lastEmit = DateTime.now();
      }
    }

    // Emit final count
    debugPrint("Metadata enrichment complete! Total: $processedCount songs");
    if (songsToUpdate.isNotEmpty) {
      _songService.updateSongsBatch(songsToUpdate);
    }
    _isEnrichmentDone = true;
    yield 1.0;
  }

  String _getFileNameWithoutExtension(String path) {
    return path.replaceAll("\\", "/").split("/").last.split('.').first;
  }
}
