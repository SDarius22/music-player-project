import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/screens/home_screen.dart';
import 'package:music_player_frontend/platforms/macos/ui/components/widgets/macos_drawer_widget.dart';
import 'package:music_player_frontend/platforms/macos/ui/components/widgets/macos_song_player_widget.dart';
import 'package:music_player_frontend/platforms/macos/ui/components/widgets/macos_top_bar_widget.dart';
import 'package:music_player_frontend/platforms/macos/ui/screens/tracks.dart';
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
  bool _didPushInitial = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didPushInitial) return;
    _didPushInitial = true;

    final appState = context.read<AbstractAppStateProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appState.innerNavigatorKey.currentState?.pushReplacement(Tracks.route());
    });
  }

  @override
  PreferredSizeWidget buildAppBar(BuildContext context) =>
      const MacosAppBarWidget();

  @override
  Widget buildSongPlayer() => const MacosSongPlayerWidget();

  @override
  EdgeInsetsGeometry buildPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return EdgeInsets.only(
      top: width * 0.01 + appWindow.titleBarHeight,
      bottom: width * 0.01,
      left: width * 0.01,
      right: width * 0.01,
    );
  }

  Route<dynamic> _buildPlaceholderRoute() {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
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
          const MacosDrawerWidget(),
          SizedBox(width: width * 0.01),
          Theme(
            data: MusicPlayerTheme.getTheme(context, context.read<Scaler>()),
            child: Expanded(
              child: HeroControllerScope(
                controller: MaterialApp.createMaterialHeroController(),
                child: Navigator(
                  key: provider.innerNavigatorKey,
                  onGenerateRoute: (_) => _buildPlaceholderRoute(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
