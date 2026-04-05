import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

class AndroidMusicScannerService implements AbstractMusicScannerService {
  final SongService _songService;
  final ArtistService _artistService;
  final AlbumService _albumService;
  final AbstractFileService _fileService;

  AndroidMusicScannerService(
    this._songService,
    this._artistService,
    this._albumService,
    this._fileService,
  );

  @override
  Future<void> performQuickScan() async {
    final songs = await _fileService.getAudioFiles(null);
    int addedCount = 0;

    for (final songModel in songs) {
      final existing = await _songService.getSong(songModel.data);
      if (existing == null) {
        _addSong(songModel);
        addedCount++;
      }
    }

    debugPrint(
      "Quick scan complete: $addedCount new songs added (${songs.length} total files found)",
    );
  }

  Future<void> _addSong(SongModel songModel) async {
    String fileHash = '';
    try {
      final bytes = await File(songModel.data).readAsBytes();
      fileHash = sha256.convert(bytes).toString();
    } catch (_) {}

    var artist = _artistService.getOrCreateArtist(
      songModel.artist ?? 'Unknown Artist',
    );
    var album = _albumService.getOrCreateAlbum(
      songModel.album ?? 'Unknown Album',
      artist.id,
      image: await _fileService.getImage(songModel.id),
    );

    final song =
        Song()
          ..path = songModel.data
          ..name = songModel.title
          ..durationInSeconds = (songModel.duration ?? 0) ~/ 1000
          ..trackNumber = songModel.track ?? 0
          ..discNumber = -1
          ..year = -1
          ..fileHash = fileHash
          ..artist.target = artist
          ..album.target = album
          ..fullyLoaded = false;

    album.songs.add(song);
    _albumService.updateAlbum(album);

    artist.songs.add(song);
    artist.albums.add(album);
    _artistService.updateArtist(artist);

    _songService.addSongEntity(song);
  }

  @override
  Stream<double> get progressStream => Stream.empty();
}
