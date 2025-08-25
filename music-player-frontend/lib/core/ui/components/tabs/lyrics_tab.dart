import 'package:flutter/material.dart';


abstract class AbstractLyricsTab extends StatelessWidget {
  final bool oneLine;
  const AbstractLyricsTab({super.key, this.oneLine = false});

  Widget _buildLyricsContent();
  BorderRadiusGeometry _borderRadius();

  @override
  Widget build(BuildContext context) {

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: Colors.black,
            borderRadius: _borderRadius()
        ),
        child: _buildLyricsContent(),
      ),
    );
  }
}