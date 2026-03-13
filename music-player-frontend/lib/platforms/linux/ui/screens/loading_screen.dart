import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/ui/screens/loading_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/widgets/linux_top_bar_widget.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/main_scaffold.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/welcome_screen.dart';
import 'package:provider/provider.dart';

class LoadingScreen extends AbstractLoadingScreen {
  const LoadingScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return const LoadingScreen();
      },
    );
  }

  @override
  LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends LoadingScreenState<LoadingScreen>
    with AfterLayoutMixin<LoadingScreen> {
  @override
  void routeUser(BuildContext context) async {
    var abstractAppStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );
    if (abstractAppStateProvider.appSettings.firstTime ||
        abstractAppStateProvider.appSettings.mainSongPlace.isEmpty) {
      Navigator.pushReplacement(context, WelcomeScreen.route());
    } else {
      final userProvider = context.read<UserProvider>();
      await userProvider.tryAutoLogin().then((_) async {
        if (!context.mounted) return;
        await context.read<SongProvider>().initialize(
          abstractAppStateProvider.appSettings.songPlaces,
        );
      });

      if (context.mounted) {
        Navigator.pushReplacement(context, LinuxMainScaffold.route());
      }
    }
  }

  @override
  PreferredSizeWidget buildAppBar(BuildContext context) {
    return const LinuxAppBarWidget();
  }
}
