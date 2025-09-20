import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class HoverWidget extends StatefulWidget {
  final Widget hoverChild;
  final Widget child;
  final void Function(PointerEnterEvent event)? onHover;
  const HoverWidget(
      {super.key,
        required this.hoverChild,
        required this.child,
        this.onHover});

  @override
  State<HoverWidget> createState() => _HoverWidgetState();
}

class _HoverWidgetState extends State<HoverWidget> {
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
        if (widget.onHover != null) {
          widget.onHover!(event);
        }
      },
      onExit: (event) {
        setState(() {
          _isHover = false;
        });
      },
      child: _isHover ? widget.hoverChild : widget.child,
    );
  }
}
