import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';

class AndroidMusicScannerService implements AbstractMusicScannerService {
  static final _logger = Logger('AndroidMusicScannerService');

  final LocalTrackService _localTrackService;
  final AbstractFileService _fileService;
  final StreamController<MusicScanProgress> _progress =
      StreamController<MusicScanProgress>.broadcast();
  bool _isScanning = false;
  bool _cancelRequested = false;

  AndroidMusicScannerService(this._localTrackService, this._fileService);

  @override
  Stream<MusicScanProgress> get progressStream => _progress.stream;

  @override
  Future<void> cancelScan() async => _cancelRequested = true;

  @override
  Future<void> performQuickScan() async {
    if (_isScanning) return;
    _isScanning = true;
    _cancelRequested = false;
    try {
      await _scan();
    } catch (error, stackTrace) {
      _logger.warning('Music scan failed', error, stackTrace);
      _progress.add(const MusicScanProgress(MusicScanPhase.failed));
    } finally {
      _isScanning = false;
    }
  }

  Future<void> _scan() async {
    _progress.add(const MusicScanProgress(MusicScanPhase.discovering));
    final mediaItems = await _fileService.getAudioFiles(null);
    final discoveredKeys = <String>{};
    final pending = <LocalTrack>[];
    _progress.add(
      MusicScanProgress(MusicScanPhase.scanning, total: mediaItems.length),
    );

    for (var index = 0; index < mediaItems.length; index++) {
      if (_cancelRequested) break;
      final item = mediaItems[index];
      final sourceKey = 'android:${item.id}';
      final sourceUri =
          item.uri?.toString().isNotEmpty == true
              ? item.uri.toString()
              : item.data.toString();
      discoveredKeys.add(sourceKey);

      int? fileSize;
      DateTime? modifiedAt;
      final dataPath = item.data.toString();
      if (dataPath.isNotEmpty) {
        try {
          final stat = await File(dataPath).stat();
          fileSize = stat.size;
          modifiedAt = stat.modified;
        } catch (_) {
          // Scoped-storage content URIs may not expose a filesystem stat.
        }
      }

      final title = _value(item.title, _fileName(dataPath));
      final artist = _value(item.artist, 'Unknown Artist');
      final album = _value(item.album, 'Unknown Album');
      final track = _localTrackService.discover(
        sourceKey: sourceKey,
        sourceUri: sourceUri,
        fallbackTitle: title,
        fileSize: fileSize,
        modifiedAt: modifiedAt,
      );
      _localTrackService.applyMetadata(
        track,
        title: title,
        artist: artist,
        album: album,
        durationInSeconds: (item.duration as int? ?? 0) ~/ 1000,
        trackNumber: item.track as int? ?? 0,
        discNumber: int.tryParse(item.disc?.toString() ?? '') ?? 0,
        year: item.year as int? ?? 0,
      );
      pending.add(track);

      if (pending.length >= 100) {
        _localTrackService.saveMany(pending);
        pending.clear();
        _progress.add(
          MusicScanProgress(
            MusicScanPhase.scanning,
            processed: index + 1,
            total: mediaItems.length,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (pending.isNotEmpty) _localTrackService.saveMany(pending);
    if (!_cancelRequested) {
      _localTrackService.reconcileMissing(discoveredKeys);
    }
    _progress.add(
      MusicScanProgress(
        _cancelRequested ? MusicScanPhase.cancelled : MusicScanPhase.completed,
        processed: discoveredKeys.length,
        total: mediaItems.length,
      ),
    );
  }

  String _value(dynamic value, String fallback) {
    final string = value?.toString().trim() ?? '';
    return string.isEmpty ? fallback : string;
  }

  String _fileName(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}
