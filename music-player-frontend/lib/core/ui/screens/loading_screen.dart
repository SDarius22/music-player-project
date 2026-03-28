import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/app_bar_widget.dart';
import 'package:music_player_frontend/core/ui/screens/main_scaffold.dart';
import 'package:music_player_frontend/core/ui/screens/welcome_screen.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/animated_background.dart';
import 'package:provider/provider.dart';
import 'package:universal_platform/universal_platform.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: "/loading"),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const LoadingScreen();
      },
    );
  }

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with AfterLayoutMixin<LoadingScreen> {
  @override
  void afterFirstLayout(BuildContext context) {
    routeUser(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
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

  void routeUser(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    await userProvider.tryAutoLogin();

    if (!context.mounted) return;

    final abstractAppStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );

    final isDesktop = UniversalPlatform.isDesktop;

    if (!userProvider.isAuthenticated ||
        (isDesktop &&
            (abstractAppStateProvider.appSettings.firstTime ||
                abstractAppStateProvider.appSettings.mainSongPlace.isEmpty))) {
      if (context.mounted) {
        Navigator.pushReplacement(context, WelcomeScreen.route());
      }
      return;
    }

    final songProvider = context.read<SongProvider>();

    if (isDesktop) {
      await songProvider.initialize(
        abstractAppStateProvider.appSettings.songPlaces,
      );
    } else {
      await songProvider.initialize([]);
    }

    // if (!context.mounted) return;
    //
    // final serverState =
    //     await context.read<PlaybackRestService>().getPlaybackState();
    // if (serverState != null && context.mounted) {
    //   await context.read<AppAudioService>().restoreFromServerState(serverState);
    // }

    if (context.mounted) {
      Navigator.pushReplacement(context, MainScaffold.route());
    }
  }
}
