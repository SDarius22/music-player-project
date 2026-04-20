import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class AndroidMusicScannerService implements AbstractMusicScannerService {
  static final _logger = Logger('AndroidMusicScannerService');

  final SongService _songService;
  final ArtistService _artistService;
  final AlbumService _albumService;
  final AbstractFileService _fileService;

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  bool _isScanning = false;

  AndroidMusicScannerService(
    this._songService,
    this._artistService,
    this._albumService,
    this._fileService,
  );

  @override
  Stream<double> get progressStream => _progressController.stream;

  @override
  Future<void> performQuickScan() async {
    if (_isScanning) return;
    _isScanning = true;
    _progressController.add(0.0);

    final songs = await _fileService.getAudioFiles(null);

    if (songs.isEmpty) {
      _isScanning = false;
      _progressController.add(1.0);
      Future.delayed(const Duration(seconds: 1), () {
        _progressController.add(2.0);
      });
      return;
    }

    int processedCount = 0;
    List<Song> songsToUpdate = [];

    for (final songModel in songs) {
      String fileHash = '';
      try {
        final bytes = await File(songModel.data).readAsBytes();
        fileHash = sha256.convert(bytes).toString();
      } catch (_) {
        _logger.warning('Failed to read file for hashing: ${songModel.data}');
        continue;
      }

      var existing = _songService.getLocalSong(fileHash);

      if (existing == null || existing.fullyLoaded == false) {
        var existingId = existing?.id ?? 0;
        existing = Song(fileHash)..path = songModel.data;
        var artistName =
            songModel.artist.trim().isEmpty
                ? 'Unknown Artist'
                : songModel.artist.trim();
        var albumName =
            songModel.album.trim().isEmpty
                ? 'Unknown Album'
                : songModel.album.trim();

        var artist = _artistService.getOrCreateArtist(artistName);

        var album = _albumService.getOrCreateAlbum(albumName, artist);

        existing
          ..id = existingId
          ..name = songModel.title
          ..durationInSeconds = (songModel.duration ?? 0) ~/ 1000
          ..trackNumber = songModel.track ?? 0
          ..discNumber = int.tryParse(songModel.disc ?? '0') ?? 0
          ..year = songModel.year
          ..artist.target = artist
          ..album.target = album
          ..fullyLoaded = false;

        songsToUpdate.add(existing);
        album.addSong(existing);
        _albumService.updateAlbum(album);

        artist.addSong(existing);
        _artistService.updateArtist(artist);
      } else {
        _logger.fine('Song already exists in library: ${songModel.data}');
        if (existing.path != songModel.data) {
          existing.path = songModel.data;
          songsToUpdate.add(existing);
        }
      }

      processedCount++;

      if (songsToUpdate.length >= 100) {
        _songService.updateSongsBatch(songsToUpdate);
        songsToUpdate.clear();

        double progress = processedCount / songs.length;
        _progressController.add(progress);

        // Yield to the event loop so the UI can paint between batches
        await Future.delayed(Duration.zero);
      }
    }

    if (songsToUpdate.isNotEmpty) {
      _songService.updateSongsBatch(songsToUpdate);
      double progress = processedCount / songs.length;
      _progressController.add(progress);
    }

    _isScanning = false;
    _progressController.add(1.0);

    Future.delayed(const Duration(seconds: 1), () {
      _progressController.add(2.0);
    });
  }
}
