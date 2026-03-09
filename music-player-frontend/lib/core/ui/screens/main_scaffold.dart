import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_animated_scaffold.dart';
import 'package:provider/provider.dart';

abstract class AbstractMainScaffold extends StatefulWidget {
  const AbstractMainScaffold({super.key});

  @override
  State<AbstractMainScaffold> createState();
}

abstract class AbstractMainScaffoldState<T extends AbstractMainScaffold>
    extends State<T> {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<AbstractAppStateProvider>();

    return GlassAnimatedScaffold(
      controller: provider.gradientController,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: buildAppBar(context),
      drawer: buildDrawer(),
      body: Padding(
        padding: buildPadding(context),
        child: Stack(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: provider.opacityNotifier,
              child: buildMainContent(),
              builder: (context, opacity, child) {
                return AnimatedOpacity(
                  opacity: opacity,
                  duration: const Duration(milliseconds: 300),
                  child: child,
                );
              },
            ),
            buildSongPlayer(),
          ],
        ),
      ),
      floatingActionButton: buildFloatingActionButton(),
      bottomNavigationBar: buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    return const PreferredSize(
      preferredSize: Size.fromHeight(0),
      child: SizedBox.shrink(),
    );
  }

  EdgeInsetsGeometry buildPadding(BuildContext context) {
    return EdgeInsets.zero;
  }

  Widget buildDrawer() {
    return const SizedBox.shrink();
  }

  Widget buildFloatingActionButton() {
    return const SizedBox.shrink();
  }

  Widget buildBottomNavigationBar() {
    return const SizedBox.shrink();
  }

  Widget buildMainContent();

  Widget buildSongPlayer();
}
