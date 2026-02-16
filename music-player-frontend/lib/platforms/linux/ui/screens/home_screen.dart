import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/screens/home_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/widgets/linux_drawer_widget.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/widgets/linux_song_player_widget.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/widgets/linux_top_bar_widget.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/tracks.dart';
import 'package:provider/provider.dart';

class HomeScreen extends AbstractHomeScreen {
  const HomeScreen({super.key});

  static Route<dynamic> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return const HomeScreen();
      },
    );
  }

  @override
  AbstractHomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends AbstractHomeScreenState<HomeScreen> {
  @override
  PreferredSizeWidget buildAppBar(BuildContext context) =>
      const LinuxAppBarWidget();

  @override
  Widget buildSongPlayer() => const LinuxSongPlayerWidget();

  @override
  EdgeInsetsGeometry buildPadding(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    return EdgeInsets.only(
      top: width * 0.01 + appWindow.titleBarHeight,
      bottom: width * 0.01,
      left: width * 0.01,
      right: width * 0.01,
    );
  }

  @override
  Widget buildMainContent() {
    final provider = context.read<AbstractAppStateProvider>();
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: width * 0.01 + height * 0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LinuxDrawerWidget(),
          SizedBox(width: width * 0.01),
          Theme(
            data: MusicPlayerTheme.getTheme(context, context.read<Scaler>()),
            child: Expanded(
              child: HeroControllerScope(
                controller: MaterialApp.createMaterialHeroController(),
                child: Navigator(
                  key: provider.navigatorKey,
                  onGenerateRoute: (settings) => Tracks.route(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
