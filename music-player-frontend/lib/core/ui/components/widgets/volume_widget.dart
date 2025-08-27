import 'package:flutter/material.dart';

class VolumeWidget extends StatefulWidget {
  const VolumeWidget({super.key});

  @override
  State<VolumeWidget> createState() => VolumeWidgetState();
}

class VolumeWidgetState extends State<VolumeWidget> {
  final ValueNotifier<bool> visible = ValueNotifier(false);

  Widget buildVolumeWidget(BuildContext context) {
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: visible,
      builder: (context, value, child) {
        return buildVolumeWidget(context);
      },
    );
  }
}
