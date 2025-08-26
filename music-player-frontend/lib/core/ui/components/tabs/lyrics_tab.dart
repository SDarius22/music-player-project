import 'package:flutter/material.dart';

abstract class AbstractLyricsTab extends StatelessWidget {
  final bool oneLine;

  const AbstractLyricsTab({super.key, this.oneLine = false});

  Widget buildLyricsContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(aspectRatio: 1.0, child: buildLyricsContent(context));
  }
}
