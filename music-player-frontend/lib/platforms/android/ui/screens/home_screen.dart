import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/local_libs/scaffold_gradient/custom_scaffold.dart';
import 'package:music_player_frontend/platforms/android/ui/components/theme.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_song_player_widget.dart';
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
    return CustomScaffold(
      controller: context.read<AbstractAppStateProvider>().gradientController,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width * 0.025,
                  right: MediaQuery.of(context).size.width * 0.025,
                  bottom: MediaQuery.of(context).size.width * 0.025,
                ),
                child: Theme(
                  data: MusicPlayerTheme.getTheme(context),
                  child: Expanded(
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
                ),
              ),
            ),
            const AndroidSongPlayerWidget(),
          ],
        ),
      ),
    );
  }
}
