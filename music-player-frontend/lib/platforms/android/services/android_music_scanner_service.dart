import 'dart:async';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/local_byte_range_reader.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/platforms/android/services/android_media_item_snapshot.dart';

/// Hash-free MediaStore discovery with incremental persistence.
///
/// Scans are hash-free and stat-free: snapshots are built from MediaStore
/// query metadata and volume-qualified content URIs. Unchanged records are
/// neither mutated nor saved. Permission/query failures abort the scan and
/// never trigger missing-source reconciliation. Slice C performs no manifest
/// validation and no direct LocalTrack persistence beyond B's discover/
/// metadata/save APIs.
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
    // Permission or query failures throw here, so a failed query can never
    // mark the persisted library missing.
    final mediaItems = await _fileService.getAudioFiles(null);
    final discoveredKeys = <String>{};
    final pending = <LocalTrack>[];
    var unchanged = 0;
    var complete = true;
    _progress.add(
      MusicScanProgress(MusicScanPhase.scanning, total: mediaItems.length),
    );

    for (var index = 0; index < mediaItems.length; index++) {
      if (_cancelRequested) break;
      final snapshot = AndroidMediaItemSnapshot.fromMediaStoreMap(
        mediaItems[index].getMap,
      );
      if (snapshot == null) {
        _logger.fine('Skipping Android media item without a usable media id');
        complete = false;
        continue;
      }
      if (!discoveredKeys.add(snapshot.sourceKey)) continue;

      final existing = _localTrackService.getBySourceKey(snapshot.sourceKey);
      if (existing != null &&
          _localTrackService.isUnchanged(
            existing,
            _localSnapshotOf(snapshot),
          ) &&
          existing.metadataLoaded &&
          existing.supportsRandomAccess == snapshot.supportsRandomAccess &&
          existing.name == snapshot.title &&
          existing.artistName == snapshot.artist &&
          existing.albumName == snapshot.album &&
          existing.durationInSeconds == snapshot.durationInSeconds &&
          existing.trackNumber == snapshot.trackNumber &&
          existing.discNumber == snapshot.discNumber &&
          existing.year == snapshot.year) {
        // No-op: unchanged records are not mutated and not saved.
        unchanged++;
      } else {
        final track = _localTrackService.discover(
          sourceKey: snapshot.sourceKey,
          sourceUri: snapshot.sourceUri,
          fallbackTitle: snapshot.title,
          fileSize: snapshot.size,
          modifiedAt: snapshot.modifiedAt,
          supportsRandomAccess: snapshot.supportsRandomAccess,
        );
        _localTrackService.applyMetadata(
          track,
          title: snapshot.title,
          artist: snapshot.artist,
          album: snapshot.album,
          durationInSeconds: snapshot.durationInSeconds,
          trackNumber: snapshot.trackNumber,
          discNumber: snapshot.discNumber,
          year: snapshot.year,
        );
        pending.add(track);
      }

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
      }
      // Yield even on warm scans so cancellation and playback stay responsive.
      if ((index + 1) % 100 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (pending.isNotEmpty) _localTrackService.saveMany(pending);
    if (!_cancelRequested && complete) {
      _localTrackService.reconcileMissing(_reconciledKeys(discoveredKeys));
    }
    _logger.fine(
      'Android scan finished: ${discoveredKeys.length} discovered, '
      '$unchanged unchanged',
    );
    _progress.add(
      MusicScanProgress(
        _cancelRequested ? MusicScanPhase.cancelled : MusicScanPhase.completed,
        processed: discoveredKeys.length,
        total: mediaItems.length,
      ),
    );
  }

  LocalSourceSnapshot _localSnapshotOf(AndroidMediaItemSnapshot snapshot) {
    return LocalSourceSnapshot(
      sourceKey: snapshot.sourceKey,
      sourceUri: snapshot.sourceUri,
      size: snapshot.size,
      modifiedAt: snapshot.modifiedAt,
      providerRevision: snapshot.providerRevision,
      supportsRandomAccess: snapshot.supportsRandomAccess,
    );
  }

  /// Missing-source reconciliation applies only to MediaStore-managed
  /// records; imported or legacy path records are never marked missing by an
  /// Android media scan.
  Set<String> _reconciledKeys(Set<String> discoveredKeys) {
    final keys = Set<String>.of(discoveredKeys);
    for (final track in _localTrackService.getAll()) {
      if (!track.sourceKey.startsWith(
        AndroidMediaItemSnapshot.sourceKeyPrefix,
      )) {
        keys.add(track.sourceKey);
      }
    }
    return keys;
  }
}
