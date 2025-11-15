import 'package:flutter/material.dart';

abstract class Scaler {
  double scale(BuildContext context, double wantedSize);

  double scaleWidth(BuildContext context, double wantedSize);

  double scaleHeight(BuildContext context, double wantedSize);
}
