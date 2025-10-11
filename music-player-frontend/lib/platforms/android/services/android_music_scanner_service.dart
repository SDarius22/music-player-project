import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

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

  @override
  Future<void> performQuickScan() async {
    final songs = await _fileService.getAudioFiles(null);
    int addedCount = 0;

    for (final songModel in songs) {
      final existing = _songService.getSong(songModel.data);
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
          ..lyricsPath = _fileService.getLyricsPath(songModel.data)
          ..name = songModel.title
          ..duration = songModel.duration ?? 0
          ..trackNumber = songModel.track ?? 0
          ..discNumber = -1
          ..year = -1
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
  Stream<double> enrichMetadata() {
    return const Stream.empty();
  }
}
