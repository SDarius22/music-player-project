import 'package:flutter/material.dart';

class VolumeWidget extends StatefulWidget {
  const VolumeWidget({
    super.key,
  });

  @override
  State<VolumeWidget> createState() => _VolumeWidgetState();
}

class _VolumeWidgetState extends State<VolumeWidget> {
  final ValueNotifier<bool> _visible = ValueNotifier(false);

  Widget _buildVolumeWidget() {
    throw UnimplementedError();
  }


  @override
  Widget build(BuildContext context) {

    return ValueListenableBuilder(
      valueListenable: _visible,
      builder: (context, value, child) {
        return _buildVolumeWidget();
      }
    );
  }
}