import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/local_libs/scaffold_gradient/glass_animated_scaffold.dart';
import 'package:music_player_frontend/platforms/android/ui/components/theme.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_drawer_widget.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_song_player_widget.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_top_bar_widget.dart';
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
      scaffoldState: context.read<AbstractAppStateProvider>().scaffoldKey,
      controller: context.read<AbstractAppStateProvider>().gradientController,
      appBar: AppBarWidget(
        title: 'MusicPlayer',
        leading: IconButton(
          icon: const Icon(FluentIcons.menu, color: Colors.white),
          tooltip: 'Open Drawer',
          onPressed: () {
            debugPrint(
              "Opening Drawer for ${context.read<AbstractAppStateProvider>().scaffoldKey.currentState?.hasDrawer}",
            );
            context
                .read<AbstractAppStateProvider>()
                .scaffoldKey
                .currentState
                ?.openDrawer();
          },
        ),
      ),
      drawer: const AndroidDrawerWidget(),
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SafeArea(
            child: ValueListenableBuilder(
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
                            context
                                .read<AbstractAppStateProvider>()
                                .navigatorKey,
                        onGenerateRoute: (settings) {
                          return Tracks.route();
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const AndroidSongPlayerWidget(),
        ],
      ),
      bottomNavigationBar: GlassContainer(
        height: kBottomNavigationBarHeight,
        color: Colors.black.withValues(alpha: 0.6),
        borderColor: Colors.transparent,
        blur: 25.0,
        elevation: 0.0,
        borderWidth: 0.0,
      ),
    );
  }
}
