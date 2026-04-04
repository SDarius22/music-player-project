import 'dart:typed_data';

abstract class BaseEntity {
  String get cloudId;

  String get name;

  set name(String value);

  Uint8List? get coverArt;

  bool get isLocal;
}
