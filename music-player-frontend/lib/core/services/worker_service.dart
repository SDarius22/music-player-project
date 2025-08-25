import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/utils/dominant_color/dominant_color.dart';

class WorkerService {
  static Future<List<Color>> getColorIsolate(Uint8List image) async {
    return compute(extractColors, image);
  }

  static Future<List<Color>> extractColors(Uint8List image) async {
    debugPrint("Extracting colors from image of size: ${image.length} bytes");
    if (image.isEmpty) {
      debugPrint("Image is empty, returning default colors");
      return [Colors.white, Colors.black];
    }
    List<Color> result = [];
    DominantColors extractor = DominantColors(bytes: image, dominantColorsCount: 2);
    var colors = extractor.extractDominantColors();
    if (colors.first.computeLuminance() > 0.15 && colors.last.computeLuminance() > 0.15) {
      result.add(colors.first);
      result.add(Colors.black);
    } else if (colors.first.computeLuminance() < 0.15 && colors.last.computeLuminance() < 0.15) {
      result.add(Colors.blue);
      result.add(colors.first);
    } else {
      if (colors.first.computeLuminance() > 0.15) {
        result.add(colors.first);
        result.add(colors.last);
      } else {
        result.add(colors.last);
        result.add(colors.first);
      }
    }
    return result;
  }
}