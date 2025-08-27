import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/ui/components/font_scaler.dart';

class LinuxFontScaler extends FontScaler {
  LinuxFontScaler._privateConstructor();

  static final LinuxFontScaler _instance =
      LinuxFontScaler._privateConstructor();

  factory LinuxFontScaler() {
    return _instance;
  }

  @override
  double scale(BuildContext context, double fontSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double baseWidth = 1920.0;
    double scaleFactor = screenWidth / baseWidth;
    return fontSize * scaleFactor;
  }
}
