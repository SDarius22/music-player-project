import 'dart:io';
import 'dart:typed_data';

import 'package:music_player_frontend/core/entities/local_track.dart';

/// Frozen B/C shared reader types. Slice B owns this file.
///
/// A [LocalSourceSnapshot] is the platform-neutral description of a local
/// source used for lifecycle comparison. Equality is conservative: a known
/// differing value means changed; absent values never prove a source
/// unchanged.
class LocalSourceSnapshot {
  final String sourceKey;
  final String sourceUri;
  final int? size;
  final DateTime? modifiedAt;
  final String? providerRevision;
  final bool supportsRandomAccess;

  const LocalSourceSnapshot({
    required this.sourceKey,
    required this.sourceUri,
    this.size,
    this.modifiedAt,
    this.providerRevision,
    this.supportsRandomAccess = false,
  });
}

/// A bounded byte range request derived from the manifest.
class LocalByteRange {
  final int offset;
  final int length;

  const LocalByteRange({required this.offset, required this.length});
}

/// Result of a platform range read. Bytes are only meaningful when
/// [sourceStable] is true and length matches the requested range.
class LocalByteRangeResult {
  final Uint8List bytes;
  final bool sourceStable;
  final LocalSourceSnapshot snapshot;

  const LocalByteRangeResult({
    required this.bytes,
    required this.sourceStable,
    required this.snapshot,
  });
}

/// Reads a bounded range from a [LocalTrack] source. Implementations return
/// null for unsupported URIs/ranges, permission failures, mutation, and short
/// non-final reads; they never return partial or unstable bytes as success.
abstract interface class LocalByteRangeReader {
  Future<LocalByteRangeResult?> read(LocalTrack track, LocalByteRange range);
}

/// Default filesystem-backed reader owned by slice B. Accepts plain paths and
/// `file://` URIs; rejects scoped content/remote schemes so they fall through
/// to a platform reader or a safe null result.
class FileLocalByteRangeReader implements LocalByteRangeReader {
  const FileLocalByteRangeReader();

  @override
  Future<LocalByteRangeResult?> read(
    LocalTrack track,
    LocalByteRange range,
  ) async {
    if (range.offset < 0 || range.length <= 0) return null;
    final path = _resolveFilePath(track.sourceUri);
    if (path == null) return null;

    RandomAccessFile? handle;
    try {
      final file = File(path);
      final before = await file.stat();
      if (before.size < range.offset + range.length) {
        // Short read / truncation: never accept bytes shorter than requested.
        return null;
      }
      handle = await file.open();
      await handle.setPosition(range.offset);
      final bytes = await handle.read(range.length);
      if (bytes.length != range.length) return null;
      final after = await file.stat();
      if (after.size != before.size ||
          after.modified.microsecondsSinceEpoch !=
              before.modified.microsecondsSinceEpoch) {
        // Source mutated during the read.
        return null;
      }
      return LocalByteRangeResult(
        bytes: bytes,
        sourceStable: true,
        snapshot: LocalSourceSnapshot(
          sourceKey: track.sourceKey,
          sourceUri: track.sourceUri,
          size: before.size,
          modifiedAt: before.modified,
          supportsRandomAccess: true,
        ),
      );
    } on FileSystemException {
      return null;
    } finally {
      await handle?.close();
    }
  }

  static String? _resolveFilePath(String sourceUri) {
    final uri = Uri.tryParse(sourceUri);
    if (uri == null || !uri.hasScheme) return sourceUri;
    if (uri.scheme == 'file') return uri.toFilePath();
    return null;
  }
}
