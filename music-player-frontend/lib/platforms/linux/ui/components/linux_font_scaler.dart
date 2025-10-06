import 'package:flutter/cupertino.dart';

class LinuxFontScaler {
  static double scale(BuildContext context, double fontSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double baseWidth = 1920.0;
    double scaleFactor = screenWidth / baseWidth;
    return fontSize * scaleFactor;
  }
}
