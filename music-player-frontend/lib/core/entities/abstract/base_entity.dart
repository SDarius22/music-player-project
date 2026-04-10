import 'dart:typed_data';

abstract class BaseEntity {
  String getName();

  String getSecondaryText();

  String getHash();

  Uint8List? getCoverArt();

  bool isLocal();

  String getImageUrl();
}
