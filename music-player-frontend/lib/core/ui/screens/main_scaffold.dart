import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/widgets/app_bar_widget.dart';
import 'package:music_player_frontend/core/ui/components/widgets/drawer_widget.dart';
import 'package:music_player_frontend/core/ui/components/widgets/song_player_widget.dart';
import 'package:music_player_frontend/core/ui/screens/home_screen.dart';
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
      appState.innerNavigatorKey.currentState?.pushReplacement(HomeScreen.route());
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AbstractAppStateProvider>();

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    if (width < 250 || height < 250) {
      return Scaffold(
        body: Center(
          child: Text(
            "Your screen is too small to display the app. Please use a device with a larger screen.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    try {
      return GlassAnimatedScaffold(
        key: provider.scaffoldKey,
        controller: provider.gradientController,
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBarWidget(),
        drawer: Drawer(
          backgroundColor: Colors.transparent,
          child:
              ResponsiveBreakpoints.of(context).isMobile
                  ? DrawerWidget(mobileDrawer: true)
                  : SizedBox.shrink(),
        ),
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
              SongPlayerWidget(),
            ],
          ),
        ),
        floatingActionButton: buildFloatingActionButton(),
      );
    } catch (e) {
      debugPrint("Error building MainScaffold: $e");
      return Scaffold(
        body: Center(
          child: Text(
            "An error occurred while loading the app.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }
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
      top: width * 0.01 + MediaQuery.of(context).padding.top + kToolbarHeight,
    );
  }

  Drawer buildDrawer() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (isMobile) {
      return Drawer(
        backgroundColor: Colors.transparent,
        child: DrawerWidget(mobileDrawer: true),
      );
    }
    return Drawer(
      backgroundColor: Colors.transparent,
      child: SizedBox.shrink(),
    );
  }

  Widget buildMainContent() {
    try {
      final provider = context.read<AbstractAppStateProvider>();
      final isMobile = ResponsiveBreakpoints.of(context).isMobile;
      final width = MediaQuery.of(context).size.width;
      final height = MediaQuery.of(context).size.height;

      final navigatorWidget = Theme(
        data: MusicPlayerTheme.getTheme(context, context.read<Scaler>()),
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
          child: navigatorWidget,
        );
      }

      return Padding(
        padding: EdgeInsets.only(bottom: width * 0.01 + height * 0.1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DrawerWidget(),
            SizedBox(width: width * 0.01),
            Expanded(child: navigatorWidget),
          ],
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
