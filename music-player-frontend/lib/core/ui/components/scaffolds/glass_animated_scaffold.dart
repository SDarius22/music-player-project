import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/ui/components/scaffolds/animated_background.dart';
import 'package:music_player_frontend/core/ui/components/scaffolds/glass_scaffold.dart';

/// A [GlassScaffold] presented over an animated mesh background.
class GlassAnimatedScaffold extends GlassScaffold {
  final AnimatedMeshGradientController controller;
  final List<Color> colors;

  const GlassAnimatedScaffold({
    super.key,
    super.scaffoldKey,
    super.appBar,
    super.body,
    super.floatingActionButton,
    super.floatingActionButtonLocation,
    super.floatingActionButtonAnimator,
    super.persistentFooterButtons,
    super.drawer,
    super.onDrawerChanged,
    super.endDrawer,
    super.onEndDrawerChanged,
    super.bottomNavigationBar,
    super.bottomSheet,
    super.backgroundColor,
    super.resizeToAvoidBottomInset,
    super.primary,
    super.drawerDragStartBehavior = DragStartBehavior.start,
    super.extendBody,
    super.extendBodyBehindAppBar,
    super.drawerScrimColor,
    super.drawerEdgeDragWidth,
    super.drawerEnableOpenDragGesture,
    super.endDrawerEnableOpenDragGesture,
    super.restorationId,
    required this.controller,
    required this.colors,
  }) : super(roundedGlass: false);

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      controller: controller,
      colors: colors,
      child: super.build(context),
    );
  }
}
