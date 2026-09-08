/// Platform-neutral snapshot of one Android media item, built purely from
/// MediaStore query metadata. Slice C owns this type.
///
/// Snapshots are constructed without filesystem stat calls, content hashing,
/// or whole-file access: size and modification time come from the MediaStore
/// query itself, and the source URI is a scoped-storage-safe content URI.
class AndroidMediaItemSnapshot {
  /// Prefix of every MediaStore-managed source key. Imported or legacy
  /// path-based records never use this prefix, which lets the scanner scope
  /// missing-source reconciliation to the records it actually manages.
  static const String sourceKeyPrefix = 'android:';

  /// Aggregate MediaStore volume that resolves items on every external
  /// volume through the platform ContentResolver.
  static const String defaultVolume = 'external';

  /// Stable MediaStore id key (`android:<id>`). Kept identical to the
  /// historical key format so persisted records and listening history are
  /// preserved without a source-key migration.
  final String sourceKey;

  /// Volume-qualified MediaStore content URI for the item.
  final String sourceUri;

  final String title;
  final String artist;
  final String album;
  final int durationInSeconds;
  final int trackNumber;
  final int discNumber;
  final int year;

  /// MediaStore-reported size in bytes, when known.
  final int? size;

  /// MediaStore-reported modification time, when known.
  final DateTime? modifiedAt;

  /// Optional provider revision. MediaStore exposes no per-item revision in
  /// this slice, so this stays null; mutation detection during reads uses
  /// size/modification metadata instead.
  final String? providerRevision;

  /// MediaStore-backed sources are seekable file descriptors.
  final bool supportsRandomAccess;

  const AndroidMediaItemSnapshot({
    required this.sourceKey,
    required this.sourceUri,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationInSeconds,
    this.trackNumber = 0,
    this.discNumber = 0,
    this.year = 0,
    this.size,
    this.modifiedAt,
    this.providerRevision,
    this.supportsRandomAccess = true,
  });

  /// Builds the MediaStore audio content URI for [mediaId] on [volume].
  /// Falls back to the aggregate external volume, which the platform
  /// ContentResolver resolves across all external volumes.
  static String contentUriFor(int mediaId, [String? volume]) {
    final trimmed = volume?.trim() ?? '';
    final effectiveVolume = trimmed.isEmpty ? defaultVolume : trimmed;
    return 'content://media/$effectiveVolume/audio/media/$mediaId';
  }

  /// Builds a snapshot from a raw MediaStore query row (the map produced by
  /// the `on_audio_query` Android cursor). Returns null when the row has no
  /// usable media id. All parsing is defensive: missing or unexpectedly
  /// typed columns degrade to null/defaults instead of throwing.
  static AndroidMediaItemSnapshot? fromMediaStoreMap(
    Map<dynamic, dynamic> info,
  ) {
    final id = _asInt(info['_id']);
    if (id == null || id < 0) return null;
    final data = _asString(info['_data']);
    final volume = _asString(info['volume_name']);
    final title = _value(_asString(info['title']), _fileName(data));
    final modifiedSeconds = _asInt(info['date_modified']);
    return AndroidMediaItemSnapshot(
      sourceKey: '$sourceKeyPrefix$id',
      sourceUri: contentUriFor(id, volume),
      title: title.isEmpty ? 'Unknown Song' : title,
      artist: _value(_asString(info['artist']), 'Unknown Artist'),
      album: _value(_asString(info['album']), 'Unknown Album'),
      durationInSeconds: (_asInt(info['duration']) ?? 0) ~/ 1000,
      trackNumber: _asInt(info['track']) ?? 0,
      discNumber: _asInt(info['disc_number']) ?? 0,
      year: _asInt(info['year']) ?? 0,
      size: _asInt(info['_size']),
      modifiedAt:
          modifiedSeconds == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(modifiedSeconds * 1000),
      providerRevision: null,
      supportsRandomAccess: true,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _asString(dynamic value) => value?.toString().trim() ?? '';

  static String _value(String value, String fallback) =>
      value.isEmpty ? fallback : value;

  static String _fileName(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}
