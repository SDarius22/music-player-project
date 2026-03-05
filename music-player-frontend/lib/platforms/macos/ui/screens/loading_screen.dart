import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/ui/screens/loading_screen.dart';
import 'package:music_player_frontend/platforms/macos/ui/components/widgets/macos_top_bar_widget.dart';
import 'package:music_player_frontend/platforms/macos/ui/screens/home_screen.dart';
import 'package:music_player_frontend/platforms/macos/ui/screens/welcome_screen.dart';
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
      var songProvider = Provider.of<SongProvider>(context, listen: false);
      await songProvider.initialize(
        abstractAppStateProvider.appSettings.songPlaces,
      );
      if (context.mounted) {
        Navigator.pushReplacement(context, HomeScreen.route());
      }
    }
  }

  @override
  PreferredSizeWidget buildAppBar(BuildContext context) {
    return const MacosAppBarWidget();
  }
}
