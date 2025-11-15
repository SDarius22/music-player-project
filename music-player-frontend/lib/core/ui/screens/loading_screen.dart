import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/animated_background.dart';

abstract class AbstractLoadingScreen extends StatefulWidget {
  const AbstractLoadingScreen({super.key});
}

abstract class LoadingScreenState<T extends AbstractLoadingScreen>
    extends State<T>
    with AfterLayoutMixin<T> {
  @override
  void afterFirstLayout(BuildContext context) {
    routeUser(context);
  }

  void routeUser(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: SafeArea(
        child: AnimatedBackground(
          controller: AnimatedMeshGradientController(),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    return const PreferredSize(
      preferredSize: Size.fromHeight(0),
      child: SizedBox.shrink(),
    );
  }
}
