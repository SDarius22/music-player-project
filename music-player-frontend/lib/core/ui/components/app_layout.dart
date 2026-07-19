import 'package:flutter/widgets.dart';

abstract final class AppLayout {
  static double pageInset(double width, {required bool mobile}) {
    final scaled = width * (mobile ? 0.04 : 0.015);
    return scaled.clamp(mobile ? 12.0 : 18.0, mobile ? 24.0 : 36.0);
  }

  static double contentInset(double width) => (width * 0.01).clamp(12.0, 32.0);

  static double contentGap(double width) => (width * 0.015).clamp(16.0, 40.0);

  static double sectionGap(double width, {required bool mobile}) =>
      (width * (mobile ? 0.075 : 0.02)).clamp(20.0, mobile ? 36.0 : 48.0);

  static double drawerWidth(double width, {required bool expanded}) =>
      (width * (expanded ? 0.125 : 0.075)).clamp(
        expanded ? 220.0 : 84.0,
        expanded ? 320.0 : 128.0,
      );

  static double homeCardHeight(double width, {required bool wide}) =>
      (width * (wide ? 0.08 : 0.14)).clamp(
        wide ? 96.0 : 160.0,
        wide ? 180.0 : 280.0,
      );

  static EdgeInsets mainScaffoldPadding(Size size, {required bool mobile}) {
    final inset = pageInset(size.width, mobile: mobile);
    return EdgeInsets.all(inset);
  }
}
