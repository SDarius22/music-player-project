import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/services/audio_content_hasher.dart';

void main() {
  test('hashFile returns lowercase SHA-256 of the exact file bytes', () async {
    final directory = await Directory.systemTemp.createTemp('audio_hasher_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/song.bin');
    await file.writeAsString('abc');

    final result = await const AudioContentHasher().hashFile(file.path);

    expect(
      result,
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
}
