import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class LinuxMusicScannerService implements AbstractMusicScannerService {
  static final _logger = Logger('LinuxMusicScannerService');

  final SongService _songService;
  final ArtistService _artistService;
  final AlbumService _albumService;
  final AbstractFileService _fileService;
  final SettingsService _settingsService;

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  bool _isScanning = false;

  LinuxMusicScannerService(
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

      String fileHash = '';
      try {
        final bytes = await File(file.path).readAsBytes();
        fileHash = sha256.convert(bytes).toString();
      } catch (_) {
        _logger.warning('Failed to read file for hashing: ${file.path}');
        continue;
      }

      var existing = _songService.getLocalSong(fileHash);

      if (existing == null) {
        existing = Song(fileHash)..path = file.path;
        try {
          final metadata = await _fileService.retrieveSong(file.path);

          var artistName =
              metadata['artist']?.trim().isEmpty == true
                  ? 'Unknown Artist'
                  : metadata['artist']?.trim() ?? 'Unknown Artist';
          var albumName =
              metadata['album']?.trim().isEmpty == true
                  ? 'Unknown Album'
                  : metadata['album']?.trim() ?? 'Unknown Album';

          var artist = _artistService.getOrCreateArtist(artistName);

          var album = _albumService.getOrCreateAlbum(albumName, artist);

          existing
            ..name =
                metadata['title'] ?? _getFileNameWithoutExtension(file.path)
            ..durationInSeconds = metadata['duration'] ?? 0
            ..trackNumber = metadata['trackNumber'] ?? 0
            ..discNumber = metadata['discNumber'] ?? 0
            ..year = metadata['year'] ?? 0
            ..artist.target = artist
            ..album.target = album
            ..fullyLoaded = true;

          songsToUpdate.add(existing);

          album.addSong(existing);
          _albumService.updateAlbum(album);

          artist.addSong(existing);
          _artistService.updateArtist(artist);
        } catch (e) {
          _logger.warning('Failed to read song metadata for ${file.path}', e);

          var artist = _artistService.getOrCreateArtist('Unknown Artist');
          var album = _albumService.getOrCreateAlbum('Unknown Album', artist);

          existing
            ..name = _getFileNameWithoutExtension(file.path)
            ..fullyLoaded = true
            ..requiresSync = true
            ..artist.target = artist
            ..album.target = album;

          songsToUpdate.add(existing);

          album.addSong(existing);
          _albumService.updateAlbum(album);

          artist.addSong(existing);
          _artistService.updateArtist(artist);
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
