import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';

class _FileService extends AbstractFileService {
  @override
  List<String> get supportedAudioExtensions => const ['mp3', 'flac'];

  @override
  Future<List> getAudioFiles(List<String>? songPlaces) async => const [];

  @override
  Future<Uint8List?> getImage(dynamic path) async => null;

  @override
  Future<Map<String, dynamic>> retrieveSong(
    String path, {
    bool withImage = false,
  }) async => <String, dynamic>{};
}

void main() {
  late Directory directory;
  late _FileService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('file-service-test');
    service = _FileService();
  });

  tearDown(() => directory.delete(recursive: true));

  test('detects supported extensions case-insensitively', () {
    expect(service.isSupportedAudioFile('/music/song.MP3'), isTrue);
    expect(service.isSupportedAudioFile('/music/song.wav'), isFalse);
  });

  test('finds and reads an adjacent lyrics file', () {
    final songPath = '${directory.path}/track.mp3';
    final lyricsPath = '${directory.path}/track.lrc';
    File(lyricsPath).writeAsStringSync('[00:00] lyrics');

    expect(service.getLyricsPath(songPath), lyricsPath);
    expect(service.getLyrics(songPath), '[00:00] lyrics');
    expect(service.getLyrics(null), '');
    expect(service.getLyrics(''), '');
  });

  test('returns empty lyrics values when sidecar does not exist', () {
    final songPath = '${directory.path}/missing.mp3';
    expect(service.getLyricsPath(songPath), '');
    expect(service.getLyrics(songPath), '');
  });

  test('exports an M3U playlist and checks file existence', () {
    final path = '${directory.path}/playlist.m3u';
    expect(service.fileExists(path), isFalse);
    service.exportPlaylist(path, ['/music/a.mp3', '/music/b.mp3']);
    expect(service.fileExists(path), isTrue);
    expect(
      File(path).readAsStringSync(),
      '#EXTM3U\n/music/a.mp3\n/music/b.mp3\n',
    );
  });

  test('createWorkaroundFile rejects a missing song', () async {
    await expectLater(service.createWorkaroundFile(null), throwsException);
  });
}
