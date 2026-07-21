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

class PlaylistImportRequest {
  const PlaylistImportRequest({
    required this.bytes,
    required this.sourceName,
    this.sourcePath,
  });

  final Uint8List bytes;
  final String sourceName;
  final String? sourcePath;
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

    await Future<void>.delayed(Duration.zero);
    final index = _LibraryIndex(_songService.getAllLocalCandidates());

    for (final entry in parsed.entries) {
      final song = await _resolve(entry, sourcePath, index);
      if (song == null) {
        unresolved.add(entry);
      } else if (seen.add(song.getHash())) {
        songs.add(song);
      }
      await Future<void>.delayed(Duration.zero);
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

  Future<Song?> _resolve(
    M3uEntry entry,
    String? sourcePath,
    _LibraryIndex index,
  ) async {
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
    }

    return _matchByPathSuffix(entry.location, resolvedPath, index);
  }

  Song? _matchByPathSuffix(
    String location,
    String? resolvedPath,
    _LibraryIndex index,
  ) {
    for (final candidatePath in {
      location,
      if (resolvedPath != null) resolvedPath,
    }) {
      final segments = _normalizedPathSegments(candidatePath);
      if (segments.isEmpty) continue;
      final candidates = index.byBasename[segments.last];
      if (candidates == null || candidates.isEmpty) continue;
      if (candidates.length == 1) return candidates.single.song;

      var bestCount = -1;
      _PathEntry? best;
      var ambiguous = false;
      for (final candidate in candidates) {
        final common = _commonSuffixLength(segments, candidate.segments);
        if (common > bestCount) {
          bestCount = common;
          best = candidate;
          ambiguous = false;
        } else if (common == bestCount) {
          ambiguous = true;
        }
      }
      if (best != null && !ambiguous) return best.song;
    }
    return null;
  }

  int _commonSuffixLength(List<String> a, List<String> b) {
    var i = a.length - 1;
    var j = b.length - 1;
    var count = 0;
    while (i >= 0 && j >= 0 && a[i] == b[j]) {
      count++;
      i--;
      j--;
    }
    return count;
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
        return _safeDecode(uri.path);
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

String _safeDecode(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return value;
  }
}

List<String> _normalizedPathSegments(String value) {
  final decoded = _safeDecode(value).replaceAll('\\', '/');
  final isAbsolute = decoded.startsWith('/');
  final parts = <String>[];
  for (final part in decoded.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..' && parts.isNotEmpty && parts.last != '..') {
      parts.removeLast();
    } else if (part != '..' || !isAbsolute) {
      parts.add(part.toLowerCase());
    }
  }
  return parts;
}

class _LibraryIndex {
  _LibraryIndex(List<Song> songs) {
    for (final song in songs) {
      final path = song.path;
      if (path == null || path.isEmpty) continue;
      final segments = _normalizedPathSegments(path);
      if (segments.isEmpty) continue;
      byBasename
          .putIfAbsent(segments.last, () => [])
          .add(_PathEntry(song, segments));
    }
  }

  final Map<String, List<_PathEntry>> byBasename = {};
}

class _PathEntry {
  const _PathEntry(this.song, this.segments);

  final Song song;
  final List<String> segments;
}
