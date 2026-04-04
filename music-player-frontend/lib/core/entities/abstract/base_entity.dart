import 'dart:typed_data';

abstract class BaseEntity {
  String get cloudId;

  String get name;

  set name(String value);

  Uint8List? get coverArt;

  bool get isLocal;

  /// Relative URL path for fetching this entity's cover art from the server.
  /// Returns null if the entity has no server-side cover (e.g. local-only).
  String? get imageUrl;
}
