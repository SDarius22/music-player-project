import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/local_libs/dominant_color/dominant_color.dart';

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
    DominantColors extractor = DominantColors(
      bytes: image,
      dominantColorsCount: 4,
    );
    return extractor.extractDominantColors();
  }
}
