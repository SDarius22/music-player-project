import 'package:flutter/material.dart';

abstract class AbstractDetailsTab extends StatelessWidget {
  final double opacity;

  const AbstractDetailsTab({super.key, required this.opacity});

  Widget buildDetailsContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(aspectRatio: 1.0, child: buildDetailsContent(context));
  }
}
