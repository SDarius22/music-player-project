import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_animated_scaffold.dart';
import 'package:provider/provider.dart';

abstract class AbstractWelcomeScreen extends StatefulWidget {
  const AbstractWelcomeScreen({super.key});
}

abstract class AbstractWelcomeScreenState<T extends AbstractWelcomeScreen>
    extends State<T> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GlassAnimatedScaffold(
      controller: context.read<AbstractAppStateProvider>().gradientController,
      appBar: buildAppBar(context),
      body: Container(
        alignment: Alignment.center,
        padding: buildPadding(context),
        child: buildBody(context),
      ),
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

  Widget buildBody(BuildContext context);
}
