import 'dart:typed_data';

abstract class BaseEntity {
  int get serverId;

  set serverId(int value);

  String get name;

  set name(String value);

  Uint8List? get coverArt;

  bool get isLocal;

  set isLocal(bool value);
}
