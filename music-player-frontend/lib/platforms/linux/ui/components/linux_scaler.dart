import 'package:flutter/material.dart';

class LinuxScaler {
  static double scale(BuildContext context, double wantedSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double baseWidth = 1920.0;
    double baseHeight = 1080.0 - kToolbarHeight;
    double widthRatio = screenWidth / baseWidth;
    double heightRatio = screenHeight / baseHeight;
    double scaleFactor = (widthRatio + heightRatio) / 2;
    return wantedSize * scaleFactor;
  }

  static double scaleWidth(BuildContext context, double wantedSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double baseWidth = 1920.0;
    return wantedSize * (screenWidth / baseWidth);
  }

  static double scaleHeight(BuildContext context, double wantedSize) {
    double screenHeight = MediaQuery.of(context).size.height;
    double baseHeight = 1080.0 - kToolbarHeight;
    return wantedSize * (screenHeight / baseHeight);
  }
}
