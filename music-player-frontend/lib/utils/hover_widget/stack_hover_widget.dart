import 'package:flutter/material.dart';

class StackHoverWidget extends StatefulWidget {
  final Widget topWidget;
  final Widget bottomWidget;
  const StackHoverWidget(
      {super.key, required this.topWidget, required this.bottomWidget});

  @override
  State<StackHoverWidget> createState() => _StackHoverWidgetState();
}

class _StackHoverWidgetState extends State<StackHoverWidget> {
  bool _isHover = false;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        setState(() {
          _isHover = true;
        });
      },
      onExit: (event) {
        setState(() {
          _isHover = false;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.bottomWidget,
          if (_isHover) widget.topWidget,
        ],
      ),
    );
  }
}
