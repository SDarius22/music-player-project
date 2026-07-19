import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/features/library/application/playlist_file_gateway.dart';

class FilePickerPlaylistFileGateway implements PlaylistFileGateway {
  const FilePickerPlaylistFileGateway();

  @override
  Future<PlaylistFileData?> pickPlaylist() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import an M3U playlist',
      type: FileType.custom,
      allowedExtensions: const ['m3u', 'm3u8'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes ?? await file.xFile.readAsBytes();
    return PlaylistFileData(name: file.name, path: file.path, bytes: bytes);
  }

  @override
  Future<bool> savePlaylist({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export playlist',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['m3u8'],
      bytes: bytes,
    );
    return kIsWeb || path != null;
  }
}
