import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/screens/settings_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/library_settings.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends AbstractSettingsScreen {
  static Route<void> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SettingsScreen();
      },
    );
  }

  const SettingsScreen({super.key});

  @override
  AbstractSettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends AbstractSettingsScreenState<SettingsScreen> {
  @override
  List<Map<String, Widget>> get settingsMap => [
    {
      "title": const Text("Library Settings"),
      "subtitle": const Text("Manage your music library settings"),
      "trailing": IconButton(
        onPressed: () {
          context
              .read<AbstractAppStateProvider>()
              .navigatorKey
              .currentState
              ?.push(LibrarySettings.route());
        },
        icon: Icon(
          FluentIcons.right,
          color: Colors.white,
          size: MediaQuery.of(context).size.height * 0.03,
        ),
      ),
    },
  ];

  @override
  EdgeInsetsGeometry buildPadding(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    return EdgeInsets.symmetric(
      horizontal: width * 0.025,
      vertical: height * 0.025,
    );
  }
}
