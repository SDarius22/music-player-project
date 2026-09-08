import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/services/local_byte_range_reader.dart';
import 'package:music_player_frontend/platforms/android/services/android_local_source_bridge.dart';

/// Android [LocalByteRangeReader] owned by slice C.
///
/// Filesystem paths and `file://` URIs are routed to B's public
/// [FileLocalByteRangeReader]; scoped-storage `content://` URIs are routed to
/// the native bounded range reader through [AndroidLocalSourceBridge].
/// Content URIs are never treated as filesystem paths here. This reader
/// performs no manifest SHA-256 validation and no LocalTrack persistence;
/// slice B owns both.
class AndroidLocalByteRangeReader implements LocalByteRangeReader {
  AndroidLocalByteRangeReader({
    AndroidLocalSourceBridge? bridge,
    LocalByteRangeReader? fileReader,
  }) : _bridge = bridge ?? AndroidLocalSourceBridge(),
       _fileReader = fileReader ?? const FileLocalByteRangeReader();

  final AndroidLocalSourceBridge _bridge;
  final LocalByteRangeReader _fileReader;

  @override
  Future<LocalByteRangeResult?> read(
    LocalTrack track,
    LocalByteRange range,
  ) async {
    final uri = Uri.tryParse(track.sourceUri);
    if (uri == null || uri.scheme != 'content') {
      return _fileReader.read(track, range);
    }
    final result = await _bridge.readRange(
      track.sourceUri,
      range.offset,
      range.length,
    );
    if (result == null) return null;
    return LocalByteRangeResult(
      bytes: result.bytes,
      sourceStable: result.sourceStable,
      snapshot: LocalSourceSnapshot(
        sourceKey: track.sourceKey,
        sourceUri: track.sourceUri,
        size: result.size,
        modifiedAt: result.modifiedAt,
        supportsRandomAccess: true,
      ),
    );
  }
}
