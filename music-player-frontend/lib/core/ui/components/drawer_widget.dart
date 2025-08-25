import 'package:flutter/material.dart';

class DrawerWidget extends StatefulWidget {
  const DrawerWidget({super.key});

  @override
  State<DrawerWidget> createState() => _DrawerWidgetState();
}

class _DrawerWidgetState extends State<DrawerWidget> {

  List<Map<String, dynamic>> getMenuItems() {
    throw UnimplementedError();
  }

  Color brighten(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final brighterHsl = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return brighterHsl.toColor();
  }

  Widget _buildDrawer() {
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    return _buildDrawer();
  }
}
