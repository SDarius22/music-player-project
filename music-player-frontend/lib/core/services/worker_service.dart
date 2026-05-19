import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/local_libs/dominant_color/dominant_color.dart';

class WorkerService {
  static final _logger = Logger('WorkerService');

  static Future<List<Color>> getColorIsolate(Uint8List image) async {
    return compute(extractColors, image);
  }

  static Future<List<Color>> extractColors(Uint8List? image) async {
    if (image == null) {
      _logger.fine('Image is null, returning default colors');
      return MusicPlayerTheme.primaryGradient.colors;
    }
    if (image.isEmpty) {
      _logger.fine('Image is empty, returning default colors');
      return MusicPlayerTheme.primaryGradient.colors;
    }

    try {
      _logger.fine(
        'Extracting colors from image of size: ${image.length} bytes',
      );
      DominantColors extractor = DominantColors(
        bytes: image,
        dominantColorsCount: 4,
      );
      final colors = extractor.extractDominantColors();
      if (colors.length == 4) return colors;

      _logger.warning(
        'Expected 4 dominant colors, got ${colors.length}; returning defaults',
      );
    } catch (e) {
      _logger.warning('Color extraction failed, returning defaults', e);
    }

    return MusicPlayerTheme.primaryGradient.colors;
  }
}
