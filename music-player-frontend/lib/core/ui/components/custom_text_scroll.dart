import 'package:flutter/material.dart';
import 'package:music_player_frontend/utils/text_scroll/text_scroll.dart';

class CustomTextScroll extends StatelessWidget {
  final String text;
  final TextStyle style;

  const CustomTextScroll(
      {super.key,
      required this.text,
      this.style = const TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)});

  @override
  Widget build(BuildContext context) {
    return TextScroll(
      text,
      mode: TextScrollMode.bouncing,
      velocity: const Velocity(pixelsPerSecond: Offset(20, 0)),
      style: style,
      pauseOnBounce: const Duration(seconds: 2),
      delayBefore: const Duration(seconds: 2),
      pauseBetween: const Duration(seconds: 2),
    );
  }
}
