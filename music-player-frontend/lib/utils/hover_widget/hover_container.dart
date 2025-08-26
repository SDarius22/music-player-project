import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class HoverContainer extends StatefulWidget {
  final Color? hoverColor;
  final Widget? child;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final Color? normalColor;
  final Decoration? foregroundDecoration;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? margin;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Clip clipBehavior;
  final void Function(PointerEnterEvent event)? onHover;
  HoverContainer(
      {super.key,
        this.hoverColor,
        this.onHover,
        this.alignment,
        this.padding,
        this.normalColor,
        this.foregroundDecoration,
        double? width,
        double? height,
        BoxConstraints? constraints,
        this.margin,
        this.transform,
        this.transformAlignment,
        this.child,
        this.clipBehavior = Clip.none,
      }) : assert(margin == null || margin.isNonNegative),
        assert(padding == null || padding.isNonNegative),
        assert(constraints == null || constraints.debugAssertIsValid()),
        constraints =
        (width != null || height != null)
            ? constraints?.tighten(width: width, height: height)
            ?? BoxConstraints.tightFor(width: width, height: height)
            : constraints;

  @override
  State<HoverContainer> createState() => _HoverContainerState();
}

class _HoverContainerState extends State<HoverContainer> {
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
      child: Container(
        alignment: widget.alignment,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _isHover ? widget.hoverColor : widget.normalColor,
        ),
        foregroundDecoration: widget.foregroundDecoration,
        constraints: widget.constraints,
        margin: widget.margin,
        transform: widget.transform,
        transformAlignment: widget.transformAlignment,
        clipBehavior: widget.clipBehavior,
        child: widget.child,
      ),
    );
  }
}
