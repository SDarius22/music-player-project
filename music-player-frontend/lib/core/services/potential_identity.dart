import 'dart:convert';

import 'package:crypto/crypto.dart';

class PotentialIdentity {
  const PotentialIdentity._();

  static String create({
    required String title,
    required String artist,
    required int durationInSeconds,
  }) {
    final normalizedTitle = _normalize(title);
    final normalizedArtist = _normalize(artist);
    final durationBucket = durationInSeconds <= 0 ? 0 : durationInSeconds ~/ 2;
    return sha256
        .convert(
          utf8.encode(
            '$normalizedTitle\u0000$normalizedArtist\u0000$durationBucket',
          ),
        )
        .toString();
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '');
}
