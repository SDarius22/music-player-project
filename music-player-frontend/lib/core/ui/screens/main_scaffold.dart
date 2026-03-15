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
      appBar: AppBarWidget(),
      drawer: buildDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 400) {
            return Center(
              child: Text(
                "This app is not optimized for small screens. Please use a larger device.",
                textAlign: TextAlign.center,
                style:
                    MusicPlayerTheme.getTheme(
                      context,
                      context.read<Scaler>(),
                    ).textTheme.headlineMedium,
              ),
            );
          } else {
            return Padding(
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
                  SongPlayerWidget(),
                ],
              ),
            );
          }
        },
      ),
      floatingActionButton: buildFloatingActionButton(),
    );
  }

  EdgeInsetsGeometry buildPadding(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final width = MediaQuery.of(context).size.width;
    if (isMobile) {
      return EdgeInsets.zero;
    }

    return EdgeInsets.only(
      left: width * 0.01,
      right: width * 0.01,
      bottom: width * 0.01,
      top: width * 0.01 + MediaQuery.of(context).padding.top,
    );
  }

  Widget buildDrawer() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (isMobile) {
      return Drawer(
        backgroundColor: Colors.transparent,
        child: DrawerWidget(mobileDrawer: true),
      );
    }
    return const SizedBox.shrink();
  }

  Widget buildMainContent() {
    try {
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
          padding: EdgeInsets.only(
            bottom: height * 0.1 + width * 0.015,
            top:
                width * 0.05 +
                MediaQuery.of(context).padding.top +
                kToolbarHeight,
            left: width * 0.015,
            right: width * 0.015,
          ),
          child: navigator,
        );
      }

      return Padding(
        padding: EdgeInsets.only(bottom: width * 0.01 + height * 0.1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [DrawerWidget(), SizedBox(width: width * 0.01), navigator],
        ),
      );
    } catch (e) {
      debugPrint("Error building main content: $e");
      return const Center(
        child: Text("An error occurred while loading the app."),
      );
    }
  }

  Widget buildFloatingActionButton() {
    return const SizedBox.shrink();
  }
}
