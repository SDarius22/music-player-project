import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';

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
  if (kIsWeb) return null;
  try {
    final dir = await getApplicationCacheDirectory();
    final coverDir = Directory('${dir.path}/cover_cache');
    if (!coverDir.existsSync()) coverDir.createSync(recursive: true);
    return File('${coverDir.path}/${_cacheKey(url)}');
  } catch (_) {
    return null;
  }
}

class LocalCachedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final Map<String, String> headers;
  final BoxFit fit;
  final void Function(Uint8List bytes)? onBytesLoaded;

  const LocalCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.headers = const {},
    this.fit = BoxFit.cover,
    this.onBytesLoaded,
  });

  @override
  State<LocalCachedNetworkImage> createState() =>
      _LocalCachedNetworkImageState();
}

class _LocalCachedNetworkImageState extends State<LocalCachedNetworkImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant LocalCachedNetworkImage old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) {
      setState(() => _future = _load());
    }
  }

  Future<Uint8List?> _load() async {
    if (widget.imageUrl.isEmpty) return null;

    // 1. Memory hit
    final mem = _MemoryCache.get(widget.imageUrl);
    if (mem != null) return mem;

    // 2. Disk hit (non-web)
    final file = await _cacheFile(widget.imageUrl);
    if (file != null && file.existsSync()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        _MemoryCache.put(widget.imageUrl, bytes);
        return bytes;
      }
    }

    // 3. Network fetch
    try {
      final response = await http.get(
        Uri.parse(widget.imageUrl),
        headers: widget.headers,
      );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        _MemoryCache.put(widget.imageUrl, bytes);
        file?.writeAsBytes(bytes, flush: true).ignore();
        widget.onBytesLoaded?.call(bytes);
        return bytes;
      }
    } catch (e) {
      debugPrint(
        'LocalCachedNetworkImage: error loading ${widget.imageUrl}: $e',
      );
    }
    return null;
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
