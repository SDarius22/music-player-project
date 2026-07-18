import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// Computes the canonical identity shared by local files and server songs.
class AudioContentHasher {
  const AudioContentHasher();

  Future<String> hashFile(String path) async {
    return Isolate.run(() => _hashFile(path));
  }
}

Future<String> _hashFile(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}
