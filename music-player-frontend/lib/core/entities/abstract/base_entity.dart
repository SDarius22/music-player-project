import 'dart:typed_data';

abstract class BaseEntity {
  bool get isLocal;

  bool get isAvailableOffline => isLocal;

  bool get isAvailableToStream;

  String getName();

  String getSecondaryText();

  String getHash();

  Uint8List? getCoverArt();

  String getImageUrl();
}
