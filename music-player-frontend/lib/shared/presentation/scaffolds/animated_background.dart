import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';

class AnimatedBackground extends StatefulWidget {
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
  final AnimatedMeshGradientController controller;
  final List<Color> colors;

  AnimatedBackground({
    super.key,
    double? width,
    double? height,
    BoxConstraints? constraints,
    this.child,
    this.alignment,
    this.padding,
    this.normalColor,
    this.foregroundDecoration,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.clipBehavior = Clip.none,
    required this.controller,
    required this.colors,
  }) : assert(margin == null || margin.isNonNegative),
       assert(padding == null || padding.isNonNegative),
       assert(constraints == null || constraints.debugAssertIsValid()),
       constraints =
           (width != null || height != null)
               ? constraints?.tighten(width: width, height: height) ??
                   BoxConstraints.tightFor(width: width, height: height)
               : constraints;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<List<Color>>(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      tween: ColorListTween(begin: widget.colors, end: widget.colors),
      builder: (context, colors, child) {
        return AnimatedMeshGradient(
          controller: widget.controller,
          colors: colors,
          options: AnimatedMeshGradientOptions(
            speed: 5,
            grain: 0.1,
            amplitude: 25,
          ),
          child: Container(
            alignment: widget.alignment,
            padding: widget.padding,
            foregroundDecoration: widget.foregroundDecoration,
            constraints: widget.constraints,
            margin: widget.margin,
            transform: widget.transform,
            transformAlignment: widget.transformAlignment,
            clipBehavior: widget.clipBehavior,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class ColorListTween extends Tween<List<Color>> {
  ColorListTween({required List<Color> begin, required List<Color> end})
    : super(begin: begin, end: end);

  @override
  List<Color> lerp(double t) {
    final length = begin!.length;
    return List.generate(length, (i) => Color.lerp(begin![i], end![i], t)!);
  }
}
