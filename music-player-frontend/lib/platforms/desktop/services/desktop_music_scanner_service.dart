import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

/// Shared filesystem scanner used by desktop platforms.
class DesktopMusicScannerService implements AbstractMusicScannerService {
  static final _logger = Logger('DesktopMusicScannerService');

  final SongService _songService;
  final ArtistService _artistService;
  final AlbumService _albumService;
  final AbstractFileService _fileService;
  final SettingsService _settingsService;
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();
  bool _isScanning = false;

  DesktopMusicScannerService(
    SongService songService,
    ArtistService artistService,
    AlbumService albumService,
    AbstractFileService fileService,
    SettingsService settingsService,
  ) : _songService = songService,
      _artistService = artistService,
      _albumService = albumService,
      _fileService = fileService,
      _settingsService = settingsService;

  AppSettings get _currentSettings => _settingsService.getAppSettings();

  @override
  Stream<double> get progressStream => _progressController.stream;

  @override
  Future<void> performQuickScan() async {
    if (_isScanning) return;
    _isScanning = true;
    _progressController.add(0.0);

    final files = await _fileService.getAudioFiles(_currentSettings.songPlaces);
    if (files.isEmpty) {
      _finishScan();
      return;
    }

    var processedCount = 0;
    final songsToUpdate = <Song>[];
    for (final file in files) {
      await Future<void>.delayed(const Duration(milliseconds: 8));
      String fileHash;
      try {
        fileHash =
            sha256.convert(await File(file.path).readAsBytes()).toString();
      } catch (_) {
        _logger.warning('Failed to read file for hashing: ${file.path}');
        continue;
      }

      var existing = _songService.getLocalSong(fileHash);
      if (existing == null || !existing.fullyLoaded) {
        existing = await _readSong(file, fileHash);
        songsToUpdate.add(existing);
      } else if (existing.path != file.path) {
        existing.path = file.path;
        songsToUpdate.add(existing);
      }

      processedCount++;
      if (songsToUpdate.length >= 100) {
        _flush(songsToUpdate, processedCount / files.length);
      }
    }

    if (songsToUpdate.isNotEmpty) {
      _flush(songsToUpdate, processedCount / files.length);
    }
    _finishScan();
  }

  Future<Song> _readSong(File file, String fileHash) async {
    final song = Song(fileHash)..path = file.path;
    try {
      final metadata = await _fileService.retrieveSong(file.path);
      final artistName = _metadataName(metadata['artist'], 'Unknown Artist');
      final albumName = _metadataName(metadata['album'], 'Unknown Album');
      final artist = _artistService.getOrCreateArtist(artistName);
      final album = _albumService.getOrCreateAlbum(albumName, artist);
      song
        ..name = metadata['title'] ?? _fileName(file.path)
        ..durationInSeconds = metadata['duration'] ?? 0
        ..trackNumber = metadata['trackNumber'] ?? 0
        ..discNumber = metadata['discNumber'] ?? 0
        ..year = metadata['year'] ?? 0
        ..artist.target = artist
        ..album.target = album
        ..fullyLoaded = true;
      _linkSong(song, artist, album);
    } catch (error) {
      _logger.warning('Failed to read song metadata for ${file.path}', error);
      final artist = _artistService.getOrCreateArtist('Unknown Artist');
      final album = _albumService.getOrCreateAlbum('Unknown Album', artist);
      song
        ..name = _fileName(file.path)
        ..fullyLoaded = true
        ..artist.target = artist
        ..album.target = album;
      _linkSong(song, artist, album);
    }
    return song;
  }

  String _metadataName(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  void _linkSong(Song song, Artist artist, Album album) {
    album.addSong(song);
    _albumService.updateAlbum(album);
    artist.addSong(song);
    _artistService.updateArtist(artist);
  }

  void _flush(List<Song> songs, double progress) {
    _songService.updateSongsBatch(List<Song>.of(songs));
    songs.clear();
    _progressController.add(progress);
  }

  void _finishScan() {
    _isScanning = false;
    _progressController.add(1.0);
    Future<void>.delayed(const Duration(seconds: 1), () {
      _progressController.add(2.0);
    });
  }

  String _fileName(String path) {
    return path.replaceAll('\\', '/').split('/').last.split('.').first;
  }
}
