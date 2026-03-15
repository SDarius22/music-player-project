import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/widgets/app_drawer.dart';
import 'package:music_player_frontend/core/ui/components/widgets/app_song_player_widget.dart';
import 'package:music_player_frontend/core/ui/screens/main_scaffold.dart';
import 'package:music_player_frontend/core/ui/screens/tracks.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

class AppMainScaffold extends AbstractMainScaffold {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return const AppMainScaffold();
      },
    );
  }

  const AppMainScaffold({super.key});

  @override
  AbstractMainScaffoldState createState() => _AppMainScaffoldState();
}

class _AppMainScaffoldState extends AbstractMainScaffoldState<AppMainScaffold> {
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
  PreferredSizeWidget buildAppBar(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).isMobile) {
      return AppBar(
        title: Text(
          "Music Player",
          style:
              MusicPlayerTheme.getTheme(
                context,
                context.read<Scaler>(),
              ).textTheme.headlineMedium,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      );
    }
    return const PreferredSize(
      preferredSize: Size.fromHeight(0),
      child: SizedBox.shrink(),
    );
  }

  @override
  Widget buildSongPlayer() => const AppSongPlayerWidget();

  @override
  EdgeInsetsGeometry buildPadding(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (isMobile) return EdgeInsets.zero;
    final width = MediaQuery.of(context).size.width;
    return EdgeInsets.all(width * 0.01);
  }

  @override
  Widget buildDrawer() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (isMobile) {
      return const AppDrawerWidget();
    }
    return const SizedBox.shrink();
  }

  @override
  Widget buildMainContent() {
    final provider = context.read<AbstractAppStateProvider>();
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final navigator = Theme(
      data: MusicPlayerTheme.getTheme(context, context.read<Scaler>()),
      child: Expanded(
        child: HeroControllerScope(
          controller: MaterialApp.createMaterialHeroController(),
          child: Navigator(
            key: provider.innerNavigatorKey,
            onGenerateRoute:
                (_) => PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const SizedBox.shrink(),
                  transitionDuration: Duration.zero,
                ),
          ),
        ),
      ),
    );

    if (isMobile) {
      return Padding(
        padding: EdgeInsets.only(bottom: height * 0.075),
        child: Row(children: [navigator]),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: width * 0.01 + height * 0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppDrawerWidget(),
          SizedBox(width: width * 0.01),
          navigator,
        ],
      ),
    );
  }
}
