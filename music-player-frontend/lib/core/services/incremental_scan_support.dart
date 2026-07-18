import 'package:music_player_frontend/core/entities/song.dart';

enum LocalFileScanAction { initializeStats, unchanged, hash }

LocalFileScanAction decideLocalFileScanAction(
  Song? knownAtPath,
  int size,
  DateTime modifiedAt,
) {
  if (knownAtPath == null) return LocalFileScanAction.hash;
  if (knownAtPath.localFileSize == null &&
      knownAtPath.localFileModifiedAt == null) {
    return LocalFileScanAction.initializeStats;
  }
  return knownAtPath.matchesLocalFileStat(size, modifiedAt)
      ? LocalFileScanAction.unchanged
      : LocalFileScanAction.hash;
}

Song attachScannedPath(Song? existing, String fileHash, String path) {
  if (existing != null && existing.fileHash != fileHash) {
    throw ArgumentError('Existing song hash does not match scanned file hash');
  }
  return (existing ?? Song(fileHash))..path = path;
}
