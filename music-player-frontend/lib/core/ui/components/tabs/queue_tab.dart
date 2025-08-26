import 'package:flutter/material.dart';

abstract class AbstractQueueTab extends StatelessWidget {
  const AbstractQueueTab({super.key});

  Widget buildQueueContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(aspectRatio: 1.0, child: buildQueueContent(context));
  }
}
