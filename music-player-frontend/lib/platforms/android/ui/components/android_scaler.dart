import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';

class AndroidScaler extends Scaler {
  @override
  double scale(BuildContext context, double wantedSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double baseWidth = 600.0;
    double baseHeight = 1920.0;
    double widthRatio = screenWidth / baseWidth;
    double heightRatio = screenHeight / baseHeight;
    double scaleFactor = (widthRatio + heightRatio) / 2;
    return wantedSize * scaleFactor;
  }

  @override
  double scaleWidth(BuildContext context, double wantedSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double baseWidth = 600.0;
    return wantedSize * (screenWidth / baseWidth);
  }

  @override
  double scaleHeight(BuildContext context, double wantedSize) {
    double screenHeight = MediaQuery.of(context).size.height;
    double baseHeight = 1920.0;

    return wantedSize * (screenHeight / baseHeight);
  }
}
