import 'package:flutter/material.dart';

enum TextScrollMode { bouncing, endless }

enum FadeBorderSide { left, right, both }

enum FadeBorderVisibility { always, auto }

class TextScroll extends StatefulWidget {
  const TextScroll(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection = TextDirection.ltr,
    this.mode = TextScrollMode.bouncing,
    this.velocity = const Velocity(pixelsPerSecond: Offset(80, 0)),
    this.delayBefore,
    this.pauseBetween,
    this.pauseOnBounce,
    this.numberOfReps,
    this.selectable = false,
    this.intervalSpaces,
    this.fadedBorder = false,
    this.fadedBorderWidth = 0.2,
    this.fadeBorderSide = FadeBorderSide.both,
    this.fadeBorderVisibility = FadeBorderVisibility.auto,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection textDirection;
  final TextScrollMode mode;
  final Velocity velocity;
  final Duration? delayBefore;
  final Duration? pauseBetween;
  final Duration? pauseOnBounce;
  final int? numberOfReps;
  final bool selectable;
  final int? intervalSpaces;
  final bool fadedBorder;
  final double? fadedBorderWidth;
  final FadeBorderSide fadeBorderSide;
  final FadeBorderVisibility fadeBorderVisibility;

  @override
  State<TextScroll> createState() => _TextScrollState();
}

class _TextScrollState extends State<TextScroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  double _containerWidth = 0;
  double _textWidth = 0;
  bool _loopActive = false;

  double get _scrollExtent =>
      (_textWidth - _containerWidth).clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 0.0);
  }

  @override
  void didUpdateWidget(TextScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _controller.stop();
      // Reset triggers _onLayout on the next frame via LayoutBuilder.
      setState(() {
        _textWidth = 0;
        _loopActive = false;
      });
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLayout(double containerWidth, BuildContext context) {
    final textWidth = _measureTextWidth(context);
    if ((containerWidth - _containerWidth).abs() < 0.5 &&
        (textWidth - _textWidth).abs() < 0.5) {
      return;
    }
    _containerWidth = containerWidth;
    _textWidth = textWidth;

    if (_scrollExtent <= 0) {
      _controller.stop();
      _controller.value = 0.0;
      _loopActive = false;
      return;
    }

    if (!_loopActive) {
      _startLoop();
    }
  }

  double _measureTextWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: widget.textDirection,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return painter.size.width;
  }

  Duration _durationFor(double pixels) {
    final speed = widget.velocity.pixelsPerSecond.dx;
    if (speed <= 0) return Duration.zero;
    return Duration(milliseconds: (pixels * 1000 / speed).round());
  }

  Future<void> _startLoop() async {
    _loopActive = true;
    _controller.stop();
    _controller.value = 0.0;

    if (widget.delayBefore != null) {
      await Future.delayed(widget.delayBefore!);
      if (!mounted) {
        _loopActive = false;
        return;
      }
    }

    int reps = 0;
    final maxReps = widget.numberOfReps;

    while (mounted) {
      if (maxReps != null && reps >= maxReps) break;

      final extent = _scrollExtent;
      if (extent <= 0) break;

      final duration = _durationFor(extent);
      if (duration == Duration.zero) break;

      if (widget.mode == TextScrollMode.bouncing) {
        try {
          await _controller.animateTo(
            1.0,
            duration: duration,
            curve: Curves.linear,
          );
        } catch (_) {
          break;
        }
        if (!mounted) break;

        if (widget.pauseOnBounce != null) {
          await Future.delayed(widget.pauseOnBounce!);
          if (!mounted) break;
        }

        try {
          await _controller.animateTo(
            0.0,
            duration: duration,
            curve: Curves.linear,
          );
        } catch (_) {
          break;
        }
        if (!mounted) break;

        if (widget.pauseOnBounce != null) {
          await Future.delayed(widget.pauseOnBounce!);
          if (!mounted) break;
        }
      } else {
        // Endless: scroll to end, then jump back to start.
        try {
          await _controller.animateTo(
            1.0,
            duration: duration,
            curve: Curves.linear,
          );
        } catch (_) {
          break;
        }
        if (!mounted) break;
        _controller.value = 0.0;
      }

      if (widget.pauseBetween != null) {
        await Future.delayed(widget.pauseBetween!);
        if (!mounted) break;
      }

      reps++;
    }

    if (mounted) _controller.value = 0.0;
    _loopActive = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onLayout(containerWidth, context);
        });

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final dx = -_controller.value * _scrollExtent;
            return ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1.0,
                child: Transform.translate(offset: Offset(dx, 0), child: child),
              ),
            );
          },
          child: Text(
            widget.text,
            style: widget.style,
            textAlign: widget.textAlign,
            textDirection: widget.textDirection,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        );
      },
    );
  }
}
