import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_animated_scaffold.dart';
import 'package:provider/provider.dart';

abstract class AbstractWelcomeScreen extends StatefulWidget {
  const AbstractWelcomeScreen({super.key});
}

abstract class AbstractWelcomeScreenState<T extends AbstractWelcomeScreen>
    extends State<T> {
  late AbstractAppStateProvider abstractAppStateProvider;

  @override
  void initState() {
    super.initState();
    abstractAppStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassAnimatedScaffold(
      controller: abstractAppStateProvider.gradientController,
      appBar: buildAppBar(context),
      body: Padding(padding: buildPadding(context), child: buildBody(context)),
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
