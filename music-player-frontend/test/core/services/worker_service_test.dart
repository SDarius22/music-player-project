import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/services/worker_service.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';

void main() {
  group('WorkerService', () {
    test('extractColors returns theme defaults when image is null', () async {
      final colors = await WorkerService.extractColors(null);

      expect(colors, MusicPlayerTheme.primaryGradient.colors);
    });

    test('extractColors returns theme defaults when image is empty', () async {
      final colors = await WorkerService.extractColors(Uint8List(0));

      expect(colors, MusicPlayerTheme.primaryGradient.colors);
    });
  });
}


