import 'dart:typed_data';

abstract class BaseEntity {
  bool get isLocal;

  String getName();

  String getSecondaryText();

  String getHash();

  Uint8List? getCoverArt();

  String getImageUrl();
}
