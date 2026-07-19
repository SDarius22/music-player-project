import 'dart:typed_data';

import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/features/library/domain/m3u_playlist.dart';

class PlaylistExportResult {
  const PlaylistExportResult({
    required this.bytes,
    required this.fileName,
    required this.exportedSongs,
    required this.skippedSongs,
  });

  final Uint8List bytes;
  final String fileName;
  final int exportedSongs;
  final List<Song> skippedSongs;
}

class PlaylistImportResult {
  const PlaylistImportResult({
    required this.playlistName,
    required this.songs,
    required this.unresolvedEntries,
  });

  final String playlistName;
  final List<Song> songs;
  final List<M3uEntry> unresolvedEntries;
}

class PlaylistTransferService {
  const PlaylistTransferService(
    this._songService, {
    M3uPlaylistCodec codec = const M3uPlaylistCodec(),
  }) : _codec = codec;

  final SongService _songService;
  final M3uPlaylistCodec _codec;

  PlaylistExportResult exportPlaylist(
    Playlist playlist,
    List<Song> songs,
    M3uExportMode mode,
  ) {
    final entries = <M3uEntry>[];
    final skipped = <Song>[];
    for (final song in songs) {
      final path = song.path?.trim();
      if (mode == M3uExportMode.compatible && (path == null || path.isEmpty)) {
        skipped.add(song);
        continue;
      }
      if (mode == M3uExportMode.portable &&
          (path == null || path.isEmpty) &&
          song.fileHash.isEmpty) {
        skipped.add(song);
        continue;
      }
      final location =
          path?.isNotEmpty == true
              ? path!
              : 'music-player://song/${Uri.encodeComponent(song.fileHash)}';
      entries.add(
        M3uEntry(
          location: location,
          durationInSeconds: song.durationInSeconds,
          title: song.name,
          artist: song.artist.target?.name,
          album: song.album.target?.name,
          fileHash: song.fileHash,
        ),
      );
    }

    return PlaylistExportResult(
      bytes: _codec.encode(
        playlistName: playlist.name,
        entries: entries,
        mode: mode,
      ),
      fileName: '${safeFileName(playlist.name)}.m3u8',
      exportedSongs: entries.length,
      skippedSongs: skipped,
    );
  }

  Future<PlaylistImportResult> importPlaylist({
    required Uint8List bytes,
    required String sourceName,
    String? sourcePath,
  }) async {
    final parsed = _codec.decode(bytes);
    final songs = <Song>[];
    final unresolved = <M3uEntry>[];
    final seen = <String>{};

    for (final entry in parsed.entries) {
      final song = await _resolve(entry, sourcePath);
      if (song == null) {
        unresolved.add(entry);
      } else if (seen.add(song.getHash())) {
        songs.add(song);
      }
    }

    return PlaylistImportResult(
      playlistName:
          parsed.name?.trim().isNotEmpty == true
              ? parsed.name!.trim()
              : _fileStem(sourceName),
      songs: songs,
      unresolvedEntries: unresolved,
    );
  }

  Future<Song?> _resolve(M3uEntry entry, String? sourcePath) async {
    final taggedHash = entry.fileHash?.trim();
    if (taggedHash?.isNotEmpty == true) {
      final byHash = await _songService.fetchSongByFileHash(taggedHash!);
      if (byHash != null) return byHash;
    }

    final appHash = _hashFromAppUri(entry.location);
    if (appHash != null) {
      final byHash = await _songService.fetchSongByFileHash(appHash);
      if (byHash != null) return byHash;
    }

    final resolvedPath = _resolvePath(entry.location, sourcePath);
    if (resolvedPath != null) {
      final exact = _songService.getLocalSongByPath(resolvedPath);
      if (exact != null) return exact;
      final normalizedPath = _normalizePath(resolvedPath);
      for (final candidate in _songService.getAllLocalSongs()) {
        if (candidate.path != null &&
            _normalizePath(candidate.path!) == normalizedPath) {
          return candidate;
        }
      }
    }

    final candidates = _songService.getAllLocalSongs().where(
      (song) => _metadataMatches(song, entry),
    );
    return candidates.length == 1 ? candidates.single : null;
  }

  bool _metadataMatches(Song song, M3uEntry entry) {
    final entryTitle = _normalize(entry.title ?? _fileStem(entry.location));
    if (entryTitle.isEmpty || _normalize(song.name) != entryTitle) return false;

    final entryArtist = _normalize(entry.artist ?? '');
    if (entryArtist.isNotEmpty &&
        _normalize(song.artist.target?.name ?? '') != entryArtist) {
      return false;
    }
    final entryAlbum = _normalize(entry.album ?? '');
    if (entryAlbum.isNotEmpty &&
        _normalize(song.album.target?.name ?? '') != entryAlbum) {
      return false;
    }
    final duration = entry.durationInSeconds;
    return duration == null ||
        duration < 0 ||
        song.durationInSeconds <= 0 ||
        (song.durationInSeconds - duration).abs() <= 2;
  }

  String? _hashFromAppUri(String location) {
    final uri = Uri.tryParse(location.trim());
    if (uri?.scheme != 'music-player' || uri?.host != 'song') return null;
    if (uri!.pathSegments.isEmpty) return null;
    return Uri.decodeComponent(uri.pathSegments.last);
  }

  String? _resolvePath(String location, String? sourcePath) {
    final value = location.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme != 'file') return null;
      try {
        return uri.toFilePath(
          windows: uri.pathSegments.firstOrNull?.contains(':') == true,
        );
      } catch (_) {
        return Uri.decodeComponent(uri.path);
      }
    }
    if (_isAbsolutePath(value) || sourcePath == null) return value;
    final separator = sourcePath.contains('\\') ? '\\' : '/';
    final normalizedSource = sourcePath.replaceAll(
      RegExp(r'[\\/]+'),
      separator,
    );
    final slash = normalizedSource.lastIndexOf(separator);
    if (slash < 0) return value;
    return '${normalizedSource.substring(0, slash)}$separator$value';
  }

  bool _isAbsolutePath(String value) =>
      value.startsWith('/') ||
      value.startsWith('\\\\') ||
      RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);

  String _normalizePath(String value) {
    final decoded = Uri.decodeComponent(value).replaceAll('\\', '/');
    final parts = <String>[];
    for (final part in decoded.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..' && parts.isNotEmpty && parts.last != '..') {
        parts.removeLast();
      } else if (part != '..' || !decoded.startsWith('/')) {
        parts.add(part);
      }
    }
    final prefix = decoded.startsWith('/') ? '/' : '';
    return '$prefix${parts.join('/')}'.toLowerCase();
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '');

  static String safeFileName(String value) {
    final safe = value.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
    return safe.isEmpty ? 'playlist' : safe;
  }

  String _fileStem(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}
