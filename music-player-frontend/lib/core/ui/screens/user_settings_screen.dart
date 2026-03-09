import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:provider/provider.dart';

abstract class AbstractUserSettingsScreen extends StatefulWidget {
  const AbstractUserSettingsScreen({super.key});
}

abstract class AbstractUserSettingsScreenState<
  T extends AbstractUserSettingsScreen
>
    extends State<T> {
  String dropDownValue = "Off";

  List<Map<String, dynamic>> get settingsMap;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: buildAppBar(context),
      body: Padding(
        padding: buildPadding(context),
        child: Consumer<AbstractAppStateProvider>(
          builder: (_, appState, _) {
            return ListView.builder(
              itemCount: settingsMap.length,
              itemBuilder: (context, index) {
                var setting = settingsMap[index];
                return ListTile(
                  title: setting['title'] as Widget?,
                  subtitle: setting['subtitle'] as Widget?,
                  trailing: setting['trailing'] as Widget?,
                );
              },
            );
          },
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

  EdgeInsetsGeometry buildPadding(BuildContext context) {
    return EdgeInsets.zero;
  }
}
