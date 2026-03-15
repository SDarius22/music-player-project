import 'package:flutter/material.dart';
import 'package:music_player_frontend/local_libs/text_scroll/text_scroll.dart';

class CustomTextScroll extends StatelessWidget {
  final String text;
  final TextStyle style;

  const CustomTextScroll({
    super.key,
    required this.text,
    this.style = const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final shouldBeAnimated = height < 200 || width < 200;
    if (shouldBeAnimated) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return TextScroll(
      text,
      mode: TextScrollMode.bouncing,
      velocity: const Velocity(pixelsPerSecond: Offset(20, 0)),
      style: style,
      pauseOnBounce: const Duration(seconds: 5),
      delayBefore: const Duration(seconds: 0),
      pauseBetween: const Duration(seconds: 5),
    );
  }
}
