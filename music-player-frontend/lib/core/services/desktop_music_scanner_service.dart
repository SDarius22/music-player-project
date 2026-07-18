import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';

class DesktopMusicScannerService implements AbstractMusicScannerService {
  final LocalTrackService localTrackService;
  final AbstractFileService fileService;
  final SettingsService settingsService;
  final Logger logger;

  final StreamController<MusicScanProgress> _progress =
      StreamController<MusicScanProgress>.broadcast();
  bool _isScanning = false;
  bool _cancelRequested = false;

  DesktopMusicScannerService(
    this.localTrackService,
    this.fileService,
    this.settingsService,
    String loggerName,
  ) : logger = Logger(loggerName);

  AppSettings get _settings => settingsService.getAppSettings();

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
      logger.warning('Music scan failed', error, stackTrace);
      _progress.add(const MusicScanProgress(MusicScanPhase.failed));
    } finally {
      _isScanning = false;
    }
  }

  Future<void> _scan() async {
    _progress.add(const MusicScanProgress(MusicScanPhase.discovering));
    final files = await fileService.getAudioFiles(_settings.songPlaces);
    final discoveredKeys = <String>{};
    final pendingWrites = <LocalTrack>[];
    final needsMetadata = <LocalTrack>[];

    _progress.add(
      MusicScanProgress(MusicScanPhase.scanning, total: files.length),
    );

    for (var index = 0; index < files.length; index++) {
      if (_cancelRequested) break;
      final path = files[index].path.toString();
      final sourceKey = path;
      discoveredKeys.add(sourceKey);

      try {
        final stat = await File(path).stat();
        final existing = localTrackService.getBySourceKey(sourceKey);
        final changed =
            existing == null ||
            existing.fileSize != stat.size ||
            existing.modifiedAt?.microsecondsSinceEpoch !=
                stat.modified.microsecondsSinceEpoch;
        final track = localTrackService.discover(
          sourceKey: sourceKey,
          sourceUri: path,
          fallbackTitle: _fileName(path),
          fileSize: stat.size,
          modifiedAt: stat.modified,
        );
        pendingWrites.add(track);
        if (changed || !track.metadataLoaded) needsMetadata.add(track);
      } catch (error) {
        logger.fine('Skipping unreadable local media $path: $error');
      }

      if (pendingWrites.length >= 100) {
        localTrackService.saveMany(pendingWrites);
        pendingWrites.clear();
        _progress.add(
          MusicScanProgress(
            MusicScanPhase.scanning,
            processed: index + 1,
            total: files.length,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (pendingWrites.isNotEmpty) {
      localTrackService.saveMany(pendingWrites);
    }
    if (!_cancelRequested) {
      localTrackService.reconcileMissing(discoveredKeys);
    }

    if (_cancelRequested) {
      _progress.add(
        MusicScanProgress(
          MusicScanPhase.cancelled,
          processed: discoveredKeys.length,
          total: files.length,
        ),
      );
      return;
    }

    // Local playback is already available. Everything below is enrichment and
    // deliberately contains no content hashing.
    _progress.add(
      MusicScanProgress(MusicScanPhase.enriching, total: needsMetadata.length),
    );
    final enriched = <LocalTrack>[];
    for (var index = 0; index < needsMetadata.length; index++) {
      if (_cancelRequested) break;
      final track = needsMetadata[index];
      try {
        final metadata = await fileService.retrieveSong(track.sourceUri);
        localTrackService.applyMetadata(
          track,
          title: _value(metadata['title'], track.name),
          artist: _value(metadata['artist'], 'Unknown Artist'),
          album: _value(metadata['album'], 'Unknown Album'),
          durationInSeconds: metadata['duration'] as int? ?? 0,
          trackNumber: metadata['trackNumber'] as int? ?? 0,
          discNumber: metadata['discNumber'] as int? ?? 0,
          year: metadata['year'] as int? ?? 0,
        );
        enriched.add(track);
      } catch (error) {
        logger.fine(
          'Metadata enrichment failed for ${track.sourceUri}: $error',
        );
      }

      if (enriched.length >= 50) {
        localTrackService.saveMany(enriched);
        enriched.clear();
        _progress.add(
          MusicScanProgress(
            MusicScanPhase.enriching,
            processed: index + 1,
            total: needsMetadata.length,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (enriched.isNotEmpty) localTrackService.saveMany(enriched);

    _progress.add(
      MusicScanProgress(
        _cancelRequested ? MusicScanPhase.cancelled : MusicScanPhase.completed,
        processed: needsMetadata.length,
        total: needsMetadata.length,
      ),
    );
  }

  String _fileName(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String _value(dynamic value, String fallback) {
    final string = value?.toString().trim() ?? '';
    return string.isEmpty ? fallback : string;
  }
}
