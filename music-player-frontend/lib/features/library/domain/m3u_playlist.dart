import 'dart:convert';
import 'dart:typed_data';

enum M3uExportMode { compatible, portable }

extension M3uExportModeLabel on M3uExportMode {
  String get label => switch (this) {
    M3uExportMode.compatible => 'Compatible M3U8',
    M3uExportMode.portable => 'Portable M3U8',
  };

  String get description => switch (this) {
    M3uExportMode.compatible =>
      'Uses real file paths for VLC and other music players. '
          'Remote-only songs are skipped.',
    M3uExportMode.portable =>
      'Adds stable song hashes for this app while retaining real paths '
          'for other players whenever possible.',
  };
}

class M3uEntry {
  const M3uEntry({
    required this.location,
    this.durationInSeconds,
    this.title,
    this.artist,
    this.album,
    this.fileHash,
  });

  final String location;
  final int? durationInSeconds;
  final String? title;
  final String? artist;
  final String? album;
  final String? fileHash;
}

class M3uPlaylist {
  const M3uPlaylist({required this.entries, this.name});

  final String? name;
  final List<M3uEntry> entries;
}

class M3uPlaylistCodec {
  const M3uPlaylistCodec();

  Uint8List encode({
    required String playlistName,
    required Iterable<M3uEntry> entries,
    required M3uExportMode mode,
  }) {
    final output =
        StringBuffer()
          ..writeln('#EXTM3U')
          ..writeln('#EXTENC:UTF-8')
          ..writeln('#PLAYLIST:${_metadata(playlistName)}');

    for (final entry in entries) {
      final artist = _metadata(entry.artist ?? 'Unknown Artist');
      final title = _metadata(entry.title ?? _fileStem(entry.location));
      final duration = entry.durationInSeconds ?? -1;
      output.writeln('#EXTINF:$duration,$artist - $title');
      if (entry.artist?.trim().isNotEmpty == true) {
        output.writeln('#EXTART:$artist');
      }
      if (entry.album?.trim().isNotEmpty == true) {
        output.writeln('#EXTALB:${_metadata(entry.album!)}');
      }
      if (mode == M3uExportMode.portable &&
          entry.fileHash?.trim().isNotEmpty == true) {
        output.writeln('#MPM-HASH:${entry.fileHash!.trim()}');
      }
      output.writeln(entry.location.trim());
    }

    return Uint8List.fromList(utf8.encode(output.toString()));
  }

  M3uPlaylist decode(Uint8List bytes) {
    var source = utf8.decode(bytes, allowMalformed: true);
    if (source.contains('\ufffd')) source = latin1.decode(bytes);
    if (source.startsWith('\ufeff')) source = source.substring(1);

    String? playlistName;
    int? duration;
    String? title;
    String? artist;
    String? album;
    String? fileHash;
    final entries = <M3uEntry>[];

    for (final rawLine in const LineSplitter().convert(source)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#')) {
        final upper = line.toUpperCase();
        if (upper.startsWith('#PLAYLIST:')) {
          playlistName = line.substring(line.indexOf(':') + 1).trim();
        } else if (upper.startsWith('#EXTINF:')) {
          final value = line.substring(line.indexOf(':') + 1);
          final comma = value.indexOf(',');
          final rawDuration = comma < 0 ? value : value.substring(0, comma);
          duration = num.tryParse(rawDuration.trim().split(' ').first)?.round();
          final display = comma < 0 ? '' : value.substring(comma + 1).trim();
          final separator = display.indexOf(' - ');
          if (separator >= 0) {
            artist = display.substring(0, separator).trim();
            title = display.substring(separator + 3).trim();
          } else if (display.isNotEmpty) {
            title = display;
          }
        } else if (upper.startsWith('#EXTART:')) {
          artist = line.substring(line.indexOf(':') + 1).trim();
        } else if (upper.startsWith('#EXTALB:')) {
          album = line.substring(line.indexOf(':') + 1).trim();
        } else if (upper.startsWith('#MPM-HASH:')) {
          fileHash = line.substring(line.indexOf(':') + 1).trim();
        }
        continue;
      }

      entries.add(
        M3uEntry(
          location: _unquote(line),
          durationInSeconds: duration,
          title: title,
          artist: artist,
          album: album,
          fileHash: fileHash,
        ),
      );
      duration = null;
      title = null;
      artist = null;
      album = null;
      fileHash = null;
    }

    return M3uPlaylist(name: playlistName, entries: entries);
  }

  String _metadata(String value) =>
      value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  String _fileStem(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}
