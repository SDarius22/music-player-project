import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class MusicScannerService {
  final SongService _songService;
  final ArtistService _artistService;
  final AlbumService _albumService;
  final FileService _fileService;

  MusicScannerService(
    this._songService,
    this._artistService,
    this._albumService,
    this._fileService,
  );

  Future<void> performQuickScan(List<String> musicDirectories) async {
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
        _artistService.updateArtist(artist);

        _songService.addSongEntity(song);
        addedCount++;
      }
    }

    debugPrint(
      "Quick scan complete: $addedCount new songs added (${files.length} total files found)",
    );
  }

  Future<void> enrichMetadata() async {
    final songs =
        _songService.getAllSongs().where((song) => !song.fullyLoaded).toList();

    if (songs.isEmpty) {
      debugPrint("No songs need metadata enrichment");
      return;
    }

    debugPrint("Enriching metadata for ${songs.length} songs...");

    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];
      try {
        // Use FileService to retrieve full metadata
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
        _songService.updateSong(song);

        album.songs.add(song);
        _albumService.updateAlbum(album);

        artist.songs.add(song);
        _artistService.updateArtist(artist);
        // Log progress every 10 songs
        if ((i + 1) % 10 == 0) {
          debugPrint("Enriched ${i + 1}/${songs.length} songs");
        }
      } catch (e) {
        debugPrint('Error extracting metadata for ${song.path}: $e');
        song.fullyLoaded = true;
        _songService.updateSong(song);
      }
    }

    debugPrint("Metadata enrichment complete!");
  }

  Future<void> enrichSingleSong(String path) async {
    try {
      // Use FileService to retrieve full metadata
      final metadata = await _fileService.retrieveSong(path, withImage: true);

      final song = _songService.getSong(path);
      if (song == null) return;

      song.fromJson(metadata);
      var artist = _artistService.getOrCreateArtist(
        metadata['artist'] ?? 'Unknown Artist',
      );
      var album = _albumService.getOrCreateAlbum(
        metadata['album'] ?? 'Unknown Album',
        artist.id,
      );
      song.artist.target = artist;
      song.album.target = album;
      song.fullyLoaded = true;

      _songService.updateSong(song);
    } catch (e) {
      debugPrint('Error extracting metadata for $path: $e');
      // Mark as having metadata anyway to avoid repeated failures
      final song = _songService.getSong(path);
      if (song != null) {
        song.fullyLoaded = true;
        _songService.updateSong(song);
      }
    }
  }

  String _getFileNameWithoutExtension(String path) {
    return path.replaceAll("\\", "/").split("/").last.split('.').first;
  }
}
