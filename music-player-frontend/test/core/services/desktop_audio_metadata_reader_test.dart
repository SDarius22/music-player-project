import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/services/desktop_audio_metadata_reader.dart';

void main() {
  test('falls back to a portable filename for an unreadable path', () async {
    final metadata = await readDesktopAudioMetadata(
      r'C:\missing\folder\fallback title.mp3',
      withImage: true,
    );

    expect(metadata, {
      'path': r'C:\missing\folder\fallback title.mp3',
      'title': 'fallback title.mp3',
    });
  });
}
