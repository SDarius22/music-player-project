import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/local_libs/miniplayer/src/miniplayer_will_pop_scope.dart';
import 'package:music_player_frontend/local_libs/miniplayer/src/utils.dart';
import 'package:music_player_frontend/local_libs/multivaluelistenablebuilder/mvlb.dart';

///Type definition for the builder function
typedef MiniplayerBuilder = Widget Function(double height, double percentage);

///Type definition for onDismiss. Will be used in a future version.
typedef DismissCallback = void Function(double percentage);

///MiniPlayer class
class MiniPlayer extends StatefulWidget {
  ///Required option to set the minimum and maximum height
  final double minHeight, maxHeight;

  ///Required option to set the minimum and maximum width
  final double minWidth, maxWidth;

  ///Option to enable and set elevation for the miniplayer
  final double elevation;

  ///Central API-Element
  ///Provides a builder with useful information
  final MiniplayerBuilder builder;

  ///Option to set the animation curve
  final Curve curve;

  ///Sets the background-color of the miniplayer
  final Color? backgroundColor;

  ///Option to set the animation duration
  final Duration duration;

  ///Allows you to use a global ValueNotifier with the current progress.
  ///This can be used to hide the BottomNavigationBar.
  final ValueNotifier<double>? valueNotifier;

  ///Gets called with the current percentage of the drag down.
  ///This can be used to control the volume of the media player.
  final void Function(double dragDownPercentage)? onDragDown;

  ///If onDismissed is set, the miniplayer can be dismissed
  final Function? onDismissed;

  //Allows you to manually control the miniplayer in code
  final MiniPlayerController? controller;

  ///Collapse by tapping anywhere in the miniplayer.
  final bool tapToCollapse;

  ///Used to set the color of the background box shadow
  final Color backgroundBoxShadow;

  ///Sets the margin around the miniplayer
  final EdgeInsets margin;

  ///Sets the border radius when minimized
  final BorderRadius? borderRadius;

  ///Sets the border radius when maximized
  final BorderRadius? maxBorderRadius;

  const MiniPlayer({
    super.key,
    required this.minHeight,
    required this.maxHeight,
    required this.minWidth,
    required this.maxWidth,
    required this.builder,
    this.curve = Curves.easeOut,
    this.elevation = 0,
    this.backgroundColor,
    this.valueNotifier,
    this.onDragDown,
    this.duration = const Duration(milliseconds: 300),
    this.onDismissed,
    this.controller,
    this.tapToCollapse = true,
    this.backgroundBoxShadow = Colors.black45,
    this.margin = EdgeInsets.zero,
    this.borderRadius,
    this.maxBorderRadius,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  late ValueNotifier<double> heightNotifier;
  late ValueNotifier<double> widthNotifier;
  ValueNotifier<double> dragDownPercentage = ValueNotifier(0);

  ///Temporary variable as long as onDismiss is deprecated. Will be removed in a future version.
  Function? onDismissed;

  ///Current position of drag gesture
  late double _dragHeight;
  late double _dragWidth;

  ///Used to determine SnapPosition
  late double _startHeight;
  late double _startWidth;

  bool dismissed = false;

  bool animating = false;

  ///Counts how many updates were required for a distance (onPanUpdate) -> necessary to calculate the drag speed
  int updateCount = 0;

  final StreamController<double> _heightController =
      StreamController<double>.broadcast();
  AnimationController? _animationController;

  void _statusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) _resetAnimationController();
  }

  void _resetAnimationController({Duration? duration}) {
    if (_animationController != null) {
      _animationController!.dispose();
    }
    _animationController = AnimationController(
      vsync: this,
      duration: duration ?? widget.duration,
    );
    _animationController!.addStatusListener(_statusListener);
    animating = false;
  }

  @override
  void initState() {
    // Create separate notifiers for height and width
    if (widget.valueNotifier == null) {
      heightNotifier = ValueNotifier(widget.minHeight);
    } else {
      heightNotifier = widget.valueNotifier!;
    }
    // Width always gets its own notifier
    widthNotifier = ValueNotifier(widget.minWidth);

    // add listener to dragDownPercentage
    if (widget.onDragDown != null) {
      dragDownPercentage.addListener(() {
        widget.onDragDown!(dragDownPercentage.value);
      });
    }

    _resetAnimationController();

    _dragHeight = heightNotifier.value;
    _dragWidth = widthNotifier.value;

    if (widget.controller != null) {
      widget.controller!.addListener(controllerListener);
    }

    if (widget.onDismissed != null) {
      onDismissed = widget.onDismissed;
    }

    super.initState();
  }

  @override
  void dispose() {
    _heightController.close();

    if (_animationController != null) {
      _animationController!.dispose();
    }

    if (widget.controller != null) {
      widget.controller!.removeListener(controllerListener);
    }

    dragDownPercentage.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (dismissed) {
      return Container();
    }

    return MiniplayerWillPopScope(
      onWillPop: () async {
        if (heightNotifier.value > widget.minHeight) {
          _snapToPosition(PanelState.min);
          return false;
        }
        return true;
      },
      child: MultiValueListenableBuilder(
        valueListenables: [heightNotifier, widthNotifier],
        builder: (context, values, _) {
          var percentage =
              ((values[0] - widget.minHeight)) /
              (widget.maxHeight - widget.minHeight);

          final currentBorderRadius = BorderRadius.lerp(
            widget.borderRadius,
            widget.maxBorderRadius,
            percentage,
          );

          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              if (percentage > 0)
                GestureDetector(
                  onTap: () => _animateToSize(),
                  child: Opacity(
                    opacity: borderDouble(
                      minRange: 0.0,
                      maxRange: 1.0,
                      value: percentage,
                    ),
                    child: Container(color: widget.backgroundColor),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: EdgeInsets.lerp(
                    widget.margin,
                    EdgeInsets.zero,
                    percentage > 0.1 ? 1.0 : percentage / 0.1,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: currentBorderRadius,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: widget.backgroundBoxShadow,
                        blurRadius: widget.elevation,
                        offset: const Offset(0.0, 4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: values[1],
                    height: values[0],
                    child: GestureDetector(
                      child: ValueListenableBuilder(
                        valueListenable: dragDownPercentage,
                        builder: (
                          BuildContext context,
                          double value,
                          Widget? child,
                        ) {
                          return Opacity(
                            opacity: borderDouble(
                              minRange: 0.0,
                              maxRange: 1.0,
                              value: 1 - value * 0.8,
                            ),
                            child: Transform.translate(
                              offset: Offset(
                                0.0,
                                widget.minHeight * value * 0.5,
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius:
                              currentBorderRadius ?? BorderRadius.zero,
                          child: Material(
                            type: MaterialType.transparency,
                            child: Container(
                              constraints: const BoxConstraints.expand(),
                              decoration: BoxDecoration(
                                color:
                                    widget.backgroundColor ??
                                    Colors.transparent,
                              ),
                              child: widget.builder(values[0], percentage),
                            ),
                          ),
                        ),
                      ),
                      onTap:
                          () =>
                              _dragHeight == widget.maxHeight &&
                                      !widget.tapToCollapse
                                  ? null
                                  : _snapToPosition(
                                    _dragHeight != widget.maxHeight
                                        ? PanelState.max
                                        : PanelState.min,
                                  ),
                      onPanStart: (details) {
                        _startHeight = _dragHeight;
                        _startWidth = _dragWidth;
                        updateCount = 0;

                        if (animating) {
                          _resetAnimationController();
                        }
                      },
                      onPanEnd: (details) async {
                        double speed =
                            (_dragHeight - _startHeight * _dragHeight <
                                    _startHeight
                                ? 1
                                : -1) /
                            updateCount *
                            100;

                        double snapPercentage = 0.005;
                        if (speed <= 4) {
                          snapPercentage = 0.2;
                        } else if (speed <= 9) {
                          snapPercentage = 0.08;
                        } else if (speed <= 50) {
                          snapPercentage = 0.01;
                        }

                        PanelState snap = PanelState.min;

                        final _percentageMax = percentageFromValueInRange(
                          min: widget.minHeight,
                          max: widget.maxHeight,
                          value: _dragHeight,
                        );

                        if (_startHeight > widget.minHeight) {
                          if (_percentageMax > 1 - snapPercentage) {
                            snap = PanelState.max;
                          }
                        } else {
                          if (_percentageMax > snapPercentage) {
                            snap = PanelState.max;
                          } else if (onDismissed != null &&
                              percentageFromValueInRange(
                                    min: widget.minHeight,
                                    max: 0,
                                    value: _dragHeight,
                                  ) >
                                  snapPercentage) {
                            snap = PanelState.dismiss;
                          }
                        }

                        _snapToPosition(snap);
                      },
                      onPanUpdate: (details) {
                        if (dismissed) return;

                        _dragHeight -= details.delta.dy;
                        updateCount++;

                        _handleSizeChange();
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  ///Determines whether the panel should be updated in height or discarded
  void _handleSizeChange({bool animation = false}) {
    // Handle height
    if (_dragHeight >= widget.minHeight) {
      if (dragDownPercentage.value != 0) dragDownPercentage.value = 0;
      if (_dragHeight > widget.maxHeight) return;
      heightNotifier.value = _dragHeight;
    } else if (onDismissed != null) {
      final percentageDown = borderDouble(
        minRange: 0.0,
        maxRange: 1.0,
        value: percentageFromValueInRange(
          min: widget.minHeight,
          max: 0,
          value: _dragHeight,
        ),
      );
      if (dragDownPercentage.value != percentageDown)
        dragDownPercentage.value = percentageDown;
      if (percentageDown >= 1 && animation && !dismissed) {
        if (onDismissed != null) onDismissed!();
        setState(() => dismissed = true);
      }
    }

    // Handle width
    if (_dragWidth >= widget.minWidth && _dragWidth <= widget.maxWidth) {
      widthNotifier.value = _dragWidth;
    } else if (_dragWidth < widget.minWidth) {
      widthNotifier.value = widget.minWidth;
    } else if (_dragWidth > widget.maxWidth) {
      widthNotifier.value = widget.maxWidth;
    }
  }

  ///Animates the panel height according to a SnapPoint
  void _snapToPosition(PanelState snapPosition) {
    switch (snapPosition) {
      case PanelState.max:
        _animateToSize(height: widget.maxHeight, width: widget.maxWidth);
        break;
      case PanelState.min:
        _animateToSize(height: widget.minHeight, width: widget.minWidth);
        break;
      case PanelState.dismiss:
        _animateToSize(height: 0);
        break;
    }
  }

  ///Animates the panel height to a specific value
  void _animateToSize({double? height, double? width, Duration? duration}) {
    if (_animationController == null) return;

    final startHeight = _dragHeight;
    final startWidth = _dragWidth;

    if (duration != null) _resetAnimationController(duration: duration);

    final endHeight = height ?? _dragHeight;
    final endWidth = width ?? _dragWidth;

    final tween = Tween<Size>(
      begin: Size(startWidth, startHeight),
      end: Size(endWidth, endHeight),
    );

    Animation<Size> animation = tween.animate(
      CurvedAnimation(parent: _animationController!, curve: widget.curve),
    );

    animation.addListener(() {
      _dragHeight = animation.value.height;
      _dragWidth = animation.value.width;
      _handleSizeChange(animation: true);
    });

    animating = true;
    _animationController!.forward(from: 0);
  }

  //Listener function for the controller
  void controllerListener() {
    if (widget.controller == null) return;
    if (widget.controller!.value == null) return;

    final controllerData = widget.controller!.value!;

    switch (controllerData.height) {
      case -1: // Min
        _animateToSize(
          height: widget.minHeight,
          width: controllerData.width ?? widget.minWidth,
          duration: controllerData.duration,
        );
        break;
      case -2: // Max
        _animateToSize(
          height: widget.maxHeight,
          width: controllerData.width ?? widget.maxWidth,
          duration: controllerData.duration,
        );
        break;
      case -3: // Dismiss
        _animateToSize(height: 0, duration: controllerData.duration);
        break;
      default: // Custom height
        _animateToSize(
          height: controllerData.height.toDouble(),
          width: controllerData.width,
          duration: controllerData.duration,
        );
        break;
    }
  }
}

///-1 Min, -2 Max, -3 Dismiss
enum PanelState { max, min, dismiss }

//ControllerData class. Used for the controller
class ControllerData {
  final int height;
  final double? width;
  final Duration? duration;

  const ControllerData(this.height, this.duration, {this.width});
}

//MiniplayerController class
class MiniPlayerController extends ValueNotifier<ControllerData?> {
  MiniPlayerController() : super(null);

  //Animates to a given height or state(expanded, dismissed, ...)
  void animateToHeight({
    double? height,
    double? width,
    PanelState? state,
    Duration? duration,
  }) {
    if (height == null && state == null) {
      throw ("Miniplayer: One of the two parameters, height or status, is required.");
    }

    if (height != null && state != null) {
      throw ("Miniplayer: Only one of the two parameters, height or status, can be specified.");
    }

    ControllerData? valBefore = value;

    if (state != null) {
      value = ControllerData(
        state.index == 0
            ? -2
            : state.index == 1
            ? -1
            : -3,
        duration,
        width: width,
      );
    } else {
      if (height! < 0) return;

      value = ControllerData(height.round(), duration, width: width);
    }

    if (valBefore == value) {
      notifyListeners();
    }
  }
}
