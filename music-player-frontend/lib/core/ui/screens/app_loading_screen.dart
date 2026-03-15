import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/ui/screens/app_main_scaffold.dart';
import 'package:music_player_frontend/core/ui/screens/app_welcome_screen.dart';
import 'package:music_player_frontend/core/ui/screens/loading_screen.dart';
import 'package:provider/provider.dart';

class AppLoadingScreen extends AbstractLoadingScreen {
  const AppLoadingScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return const AppLoadingScreen();
      },
    );
  }

  @override
  LoadingScreenState createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends LoadingScreenState<AppLoadingScreen> {
  @override
  void routeUser(BuildContext context) async {
    final abstractAppStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );

    // Desktop platforms have a firstTime/welcome flow; mobile/web skip it
    final isDesktop =
        !kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

    if (isDesktop &&
        (abstractAppStateProvider.appSettings.firstTime ||
            abstractAppStateProvider.appSettings.mainSongPlace.isEmpty)) {
      if (context.mounted) {
        Navigator.pushReplacement(context, AppWelcomeScreen.route());
      }
      return;
    }

    final userProvider = context.read<UserProvider>();
    await userProvider.tryAutoLogin();

    if (!context.mounted) return;

    final songProvider = context.read<SongProvider>();
    songProvider.preferServer = true;
    songProvider.fallbackToServer = true;

    if (isDesktop) {
      await songProvider.initialize(
        abstractAppStateProvider.appSettings.songPlaces,
      );
    } else {
      await songProvider.initialize([]);
    }

    if (context.mounted) {
      Navigator.pushReplacement(context, AppMainScaffold.route());
    }
  }
}