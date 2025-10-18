import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/scaffold_gradient/glass_animated_scaffold.dart';
import 'package:music_player_frontend/platforms/android/ui/components/theme.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_nav_bar.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_song_player_widget.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_top_bar_widget.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/settings_screen.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/tracks.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/home'),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const HomeScreen();
      },
    );
  }

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassAnimatedScaffold(
      controller: context.read<AbstractAppStateProvider>().gradientController,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBarWidget(
        title: "Music Player",
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.settings),
            color: Colors.white,
            onPressed: () {
              context
                  .read<AbstractAppStateProvider>()
                  .navigatorKey
                  .currentState
                  ?.push(SettingsScreen.route());
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable:
                context.read<AbstractAppStateProvider>().opacityNotifier,
            builder: (context, opacityNotifier, child) {
              return AnimatedOpacity(
                opacity: opacityNotifier,
                duration: const Duration(milliseconds: 100),
                child: Theme(
                  data: MusicPlayerTheme.getTheme(context),
                  child: HeroControllerScope(
                    controller: MaterialApp.createMaterialHeroController(),
                    child: Navigator(
                      key:
                          context.read<AbstractAppStateProvider>().navigatorKey,
                      onGenerateRoute: (settings) {
                        return Tracks.route();
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const AndroidSongPlayerWidget(),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable:
            context.read<AbstractAppStateProvider>().opacityNotifier,
        builder: (context, opacityNotifier, child) {
          return AnimatedOpacity(
            opacity: opacityNotifier,
            duration: const Duration(milliseconds: 100),
            child: const AndroidNavigationBar(),
          );
        },
      ),
    );
  }
}
