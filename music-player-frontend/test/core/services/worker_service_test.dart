import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
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

    test('extractColors handles tiny images', () async {
      final image = image_lib.Image(width: 1, height: 1);
      image.setPixelRgba(0, 0, 255, 0, 0, 255);

      final colors = await WorkerService.extractColors(
        Uint8List.fromList(image_lib.encodePng(image)),
      );

      expect(colors, hasLength(4));
    });
  });
}
