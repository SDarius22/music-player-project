import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/screens/home_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_nav_bar.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_song_player_widget.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_top_bar_widget.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/settings_screen.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/tracks.dart';
import 'package:provider/provider.dart';

class HomeScreen extends AbstractHomeScreen {
  const HomeScreen({super.key});

  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/home'),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const HomeScreen();
      },
    );
  }

  @override
  AbstractHomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends AbstractHomeScreenState<HomeScreen> {
  late final HeroController _heroController;

  @override
  void initState() {
    super.initState();
    _heroController = MaterialApp.createMaterialHeroController();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  PreferredSizeWidget buildAppBar(BuildContext context) {
    return AppBarWidget(
      title: "Music Player",
      actions: [
        IconButton(
          icon: const Icon(FluentIcons.settings),
          color: Colors.white,
          onPressed: () {
            context
                .read<AbstractAppStateProvider>()
                .innerNavigatorKey
                .currentState
                ?.push(SettingsScreen.route());
          },
        ),
      ],
    );
  }

  @override
  Widget buildSongPlayer() => const AndroidSongPlayerWidget();

  @override
  Widget buildBottomNavigationBar() {
    return ValueListenableBuilder(
      valueListenable: context.read<AbstractAppStateProvider>().opacityNotifier,
      builder: (context, opacityNotifier, child) {
        return AnimatedOpacity(
          opacity: opacityNotifier,
          duration: const Duration(milliseconds: 100),
          child: const AndroidNavigationBar(),
        );
      },
    );
  }

  @override
  Widget buildMainContent() {
    final provider = context.read<AbstractAppStateProvider>();

    return Padding(
      padding: EdgeInsets.only(
        top: kToolbarHeight + MediaQuery.of(context).size.height * 0.075,
      ),
      child: Theme(
        data: MusicPlayerTheme.getTheme(context, context.read<Scaler>()),
        child: HeroControllerScope.none(
          child: Navigator(
            key: provider.innerNavigatorKey,
            observers: [_heroController],
            onGenerateRoute: (settings) {
              return Tracks.route(provider: context.read<SongProvider>());
            },
          ),
        ),
      ),
    );
  }
}
