import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/song_provider.dart';
import 'package:music_player_frontend/features/auth/presentation/providers/user_provider.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/features/navigation/presentation/widgets/app_bar.dart';
import 'package:music_player_frontend/shared/presentation/navigation/route_builder.dart';
import 'package:music_player_frontend/features/navigation/presentation/screens/main_scaffold.dart';
import 'package:music_player_frontend/features/auth/presentation/screens/welcome_screen.dart';
import 'package:music_player_frontend/shared/presentation/scaffolds/animated_background.dart';
import 'package:music_player_frontend/shared/presentation/scaffolds/glass_animated_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:universal_platform/universal_platform.dart';

final _logger = Logger('LoadingScreen');

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  static Route<void> route() {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => const LoadingScreen(),
      settings: const RouteSettings(name: "/loading"),
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
    final appState = context.watch<AbstractAppStateProvider>();
    return GlassAnimatedScaffold(
      controller: appState.gradientController,
      colors: appState.colors,
      appBar: MusicPlayerAppBar(),
      body: SafeArea(
        child: AnimatedBackground(
          controller: AnimatedMeshGradientController(),
          colors: appState.colors,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
    );
  }

  void routeUser(BuildContext context) async {
    final abstractAppStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );

    final userProvider = context.read<UserProvider>();
    await userProvider.tryAutoLogin();

    if (!context.mounted) return;

    final isDesktop = UniversalPlatform.isDesktop;

    if ((!userProvider.isAuthenticated) ||
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

    if (!context.mounted) return;

    try {
      await context.read<AppAudioService>().initializeAppAudio();
    } catch (e, stackTrace) {
      _logger.warning(
        'Audio initialization failed; continuing into the app',
        e,
        stackTrace,
      );
    }

    if (context.mounted) {
      // Starting the scan does not block navigation. Trigger it while this
      // provider context is still alive; a callback attached to the replaced
      // loading route is not reliable on mobile.
      songProvider.startBackgroundScan();
      Navigator.pushReplacement(context, MainScaffold.route());
    }
  }
}
