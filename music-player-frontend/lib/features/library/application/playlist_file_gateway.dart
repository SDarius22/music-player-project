import 'dart:typed_data';

class PlaylistFileData {
  const PlaylistFileData({required this.name, required this.bytes, this.path});

  final String name;
  final Uint8List bytes;
  final String? path;
}

abstract class PlaylistFileGateway {
  Future<PlaylistFileData?> pickPlaylist();

  Future<bool> savePlaylist({
    required String fileName,
    required Uint8List bytes,
  });
}
