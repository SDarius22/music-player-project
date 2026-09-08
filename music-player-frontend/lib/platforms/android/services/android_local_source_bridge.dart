import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// Raw result of a native bounded content-URI range read.
///
/// Bytes are at most the requested length; [sourceStable] is the native
/// before/after size and modification comparison. Slice B performs the
/// manifest SHA-256 validation on top of this result.
class AndroidNativeReadResult {
  final Uint8List bytes;
  final int? size;
  final DateTime? modifiedAt;
  final bool sourceStable;

  const AndroidNativeReadResult({
    required this.bytes,
    this.size,
    this.modifiedAt,
    required this.sourceStable,
  });
}

/// Thin MethodChannel wrapper around the Kotlin bounded content-URI reader.
///
/// Every native/provider failure (permission loss, unsupported range access,
/// non-seekable source, mutation, short read, missing handler) maps to a safe
/// null result. This bridge never copies or hashes whole sources, never
/// passes content URIs to filesystem APIs, and never touches LocalTrack
/// persistence. Private media identifiers are not logged.
class AndroidLocalSourceBridge {
  static const String channelName = 'music_player_frontend/local_source_reader';
  static const int maxRangeBytes = 1024 * 1024;

  static final _logger = Logger('AndroidLocalSourceBridge');

  final MethodChannel _channel;

  AndroidLocalSourceBridge([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName);

  /// Reads exactly [length] bytes at [offset] from the content URI
  /// [sourceUri] through the platform ContentResolver, or returns null when
  /// the native side cannot satisfy the read safely.
  Future<AndroidNativeReadResult?> readRange(
    String sourceUri,
    int offset,
    int length,
  ) async {
    if (Uri.tryParse(sourceUri)?.scheme != 'content' ||
        offset < 0 ||
        length <= 0 ||
        length > maxRangeBytes) {
      return null;
    }
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'readRange',
        <String, dynamic>{
          'sourceUri': sourceUri,
          'offset': offset,
          'length': length,
        },
      );
      final parsed = _parse(result);
      if (parsed == null ||
          !parsed.sourceStable ||
          parsed.bytes.length != length) {
        return null;
      }
      return parsed;
    } on PlatformException catch (error) {
      _logger.fine('Native range read failed: ${error.code}');
      return null;
    } on MissingPluginException {
      _logger.fine('Native source reader is not registered');
      return null;
    }
  }

  AndroidNativeReadResult? _parse(Map<dynamic, dynamic>? result) {
    if (result == null) return null;
    final bytes = result['bytes'];
    if (bytes is! Uint8List) return null;
    final size = result['size'];
    final modifiedAtMs = result['modifiedAtMs'];
    return AndroidNativeReadResult(
      bytes: bytes,
      size: size is int ? size : null,
      modifiedAt:
          modifiedAtMs is int
              ? DateTime.fromMillisecondsSinceEpoch(modifiedAtMs)
              : null,
      sourceStable: result['sourceStable'] == true,
    );
  }
}
