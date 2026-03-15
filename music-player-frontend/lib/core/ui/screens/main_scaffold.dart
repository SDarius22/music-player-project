import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/widgets/app_bar_widget.dart';
import 'package:music_player_frontend/core/ui/components/widgets/drawer_widget.dart';
import 'package:music_player_frontend/core/ui/components/widgets/song_player_widget.dart';
import 'package:music_player_frontend/core/ui/screens/tracks.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_animated_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:universal_platform/universal_platform.dart';

class MainScaffold extends StatefulWidget {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: "/"),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const MainScaffold();
      },
    );
  }

  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
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
  Widget build(BuildContext context) {
    final provider = context.read<AbstractAppStateProvider>();

    return GlassAnimatedScaffold(
      key: provider.scaffoldKey,
      controller: provider.gradientController,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: buildAppBar(),
      drawer: buildDrawer(),
      body: Padding(
        padding: buildPadding(context),
        child: Stack(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: provider.opacityNotifier,
              child: buildMainContent(),
              builder: (context, opacity, child) {
                return AnimatedOpacity(
                  opacity: opacity,
                  duration: const Duration(milliseconds: 300),
                  child: child,
                );
              },
            ),
            buildSongPlayer(),
          ],
        ),
      ),
      floatingActionButton: buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget buildAppBar() {
    if (UniversalPlatform.isWeb) {
      return const PreferredSize(
        preferredSize: Size.fromHeight(0),
        child: SizedBox.shrink(),
      );
    }
    return AppBarWidget();
  }

  Widget buildSongPlayer() => const SongPlayerWidget();

  EdgeInsetsGeometry buildPadding(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (isMobile || kIsWeb) return EdgeInsets.zero;
    final width = MediaQuery.of(context).size.width;
    return EdgeInsets.only(
      left: width * 0.01,
      right: width * 0.01,
      bottom: width * 0.01,
      top: width * 0.01 + MediaQuery.of(context).padding.top + kToolbarHeight,
    );
  }

  Widget buildDrawer() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (isMobile) {
      return const DrawerWidget();
    }
    return const SizedBox.shrink();
  }

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
                  pageBuilder: (_, _, _) => const SizedBox.shrink(),
                  transitionDuration: Duration(milliseconds: 300),
                  reverseTransitionDuration: Duration(milliseconds: 300),
                ),
          ),
        ),
      ),
    );

    if (isMobile) {
      return Padding(
        padding: EdgeInsets.only(bottom: height * 0.075),
        child: navigator,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: width * 0.01 + height * 0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DrawerWidget(),
          SizedBox(width: width * 0.01),
          navigator,
        ],
      ),
    );
  }

  Widget buildFloatingActionButton() {
    return const SizedBox.shrink();
  }
}
