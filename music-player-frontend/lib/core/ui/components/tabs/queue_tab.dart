import 'package:flutter/material.dart';

abstract class AbstractQueueTab extends StatelessWidget {
  const AbstractQueueTab({super.key});

  BorderRadiusGeometry _borderRadius();
  Widget _buildQueueContent();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          color: Colors.black,
          borderRadius: _borderRadius(),
        ),
        child: _buildQueueContent(),
      ),
    );
  }
}