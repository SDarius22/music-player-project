import 'dart:typed_data';

final class ChunkAssembly {
  ChunkAssembly(this.fragmentCount);

  final int fragmentCount;
  final Map<int, Uint8List> fragments = {};
  int totalBytes = 0;

  bool addFragment(int index, Uint8List payload) {
    if (fragments.containsKey(index)) return false;
    fragments[index] = payload;
    totalBytes += payload.length;
    return true;
  }

  bool get isComplete => fragments.length == fragmentCount;

  Uint8List? assemble() {
    if (!isComplete) return null;

    final data = Uint8List(totalBytes);
    var offset = 0;
    for (var i = 0; i < fragmentCount; i++) {
      final part = fragments[i];
      if (part == null) return null;
      data.setAll(offset, part);
      offset += part.length;
    }
    return data;
  }
}
