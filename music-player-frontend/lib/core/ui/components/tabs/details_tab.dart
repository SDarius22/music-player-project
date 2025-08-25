import 'package:flutter/material.dart';


abstract class AbstractDetailsTab extends StatelessWidget {
  final double opacity;
  const AbstractDetailsTab({super.key, required this.opacity});

  BorderRadiusGeometry _borderRadius();
  ImageProvider _getImage();
  Widget _buildDetailsContent();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: Colors.black,
            borderRadius: _borderRadius(),
            image: DecorationImage(
              fit: BoxFit.cover,
              image: _getImage(),
            )
        ),
        child: _buildDetailsContent(),
      ),
    );
  }
}