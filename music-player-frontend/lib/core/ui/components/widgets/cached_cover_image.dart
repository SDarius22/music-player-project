import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluenticons/fluenticons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:universal_platform/universal_platform.dart';

class _MemoryCache {
  _MemoryCache._();

  static const int _maxEntries = 25;
  static final LinkedHashMap<String, Uint8List> _store =
      LinkedHashMap<String, Uint8List>();

  static Uint8List? get(String key) {
    final bytes = _store.remove(key);
    if (bytes == null) return null;
    _store[key] = bytes; // reinsert at the end (most-recently-used)
    return bytes;
  }

  static void put(String key, Uint8List bytes) {
    _store.remove(key); // remove first so reinsertion lands at the end
    _store[key] = bytes;
    if (_store.length > _maxEntries) {
      _store.remove(_store.keys.first); // evict least-recently-used
    }
  }
}

String _cacheKey(String url) => sha256.convert(utf8.encode(url)).toString();

Future<File?> _cacheFile(String url) async {
  if (UniversalPlatform.isWeb) return null;
  try {
    final dir = await getApplicationCacheDirectory();
    final coverDir = Directory('${dir.path}/cover_cache');
    if (!coverDir.existsSync()) coverDir.createSync(recursive: true);
    return File('${coverDir.path}/${_cacheKey(url)}');
  } catch (_) {
    return null;
  }
}

class CachedCoverImage extends StatefulWidget {
  final String imageUrl;
  final String? cacheKey;
  final Map<String, String> headers;
  final BoxFit fit;
  final void Function(Uint8List bytes)? onBytesLoaded;
  final Future<Uint8List?> Function(String path)? localImageLoader;
  final String? path;

  const CachedCoverImage({
    super.key,
    required this.imageUrl,
    this.cacheKey,
    this.headers = const {},
    this.fit = BoxFit.cover,
    this.onBytesLoaded,
    this.localImageLoader,
    this.path,
  });

  @override
  State<CachedCoverImage> createState() => _CachedCoverImageState();
}

class _CachedCoverImageState extends State<CachedCoverImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant CachedCoverImage old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl ||
        old.cacheKey != widget.cacheKey ||
        old.path != widget.path) {
      _future = _load();
      setState(() {});
    }
  }

  Future<Uint8List?> _load() async {
    if (widget.imageUrl.isEmpty && widget.path == null) return null;
    final cacheKey = widget.cacheKey ?? widget.imageUrl;

    final mem = _MemoryCache.get(cacheKey);
    if (mem != null) return _bytesLoaded(mem);

    final file = await _cacheFile(cacheKey);
    if (file != null && file.existsSync()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        _MemoryCache.put(cacheKey, bytes);
        return _bytesLoaded(bytes);
      }
    }

    if (widget.path != null && widget.localImageLoader != null) {
      try {
        final bytes = await widget.localImageLoader!(widget.path!);
        if (bytes == null) {
          throw Exception('File service returned null for ${widget.path!}');
        }
        if (bytes.isNotEmpty) {
          _MemoryCache.put(cacheKey, bytes);
          file?.writeAsBytes(bytes, flush: true).ignore();
          return _bytesLoaded(bytes);
        }
      } catch (e) {
        debugPrint(
          'CachedCoverImage: error loading from file service ${widget.path}: $e',
        );
      }
    }

    if (widget.imageUrl.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse(widget.imageUrl),
        headers: widget.headers,
      );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        if (!widget.imageUrl.contains('playlists')) {
          _MemoryCache.put(cacheKey, bytes);
          file?.writeAsBytes(bytes, flush: true).ignore();
        }
        return _bytesLoaded(bytes);
      }
      throw HttpException(
        'Failed to load image: ${response.statusCode} ${response.reasonPhrase}',
      );
    } catch (e) {
      debugPrint('CachedCoverImage: error loading ${widget.imageUrl}: $e');
    }
    return null;
  }

  Uint8List _bytesLoaded(Uint8List bytes) {
    widget.onBytesLoaded?.call(bytes);
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[800]!,
            highlightColor: Colors.grey[700]!,
            child: Container(color: Colors.black),
          );
        }

        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(bytes, fit: widget.fit);
        }

        return Container(
          color: Colors.black,
          child: Icon(
            FluentIcons.music,
            color: Colors.white.withValues(alpha: 0.25),
            size: 64,
          ),
        );
      },
    );
  }
}
