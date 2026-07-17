import 'package:flutter/material.dart';

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
    return Text(
      text,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
