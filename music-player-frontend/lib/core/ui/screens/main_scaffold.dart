import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/app_layout.dart';
import 'package:music_player_frontend/core/ui/components/widgets/app_bar_widget.dart';
import 'package:music_player_frontend/core/ui/components/widgets/drawer_widget.dart';
import 'package:music_player_frontend/core/ui/components/widgets/song_player_widget.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/route_builder.dart';
import 'package:music_player_frontend/core/ui/screens/home_screen.dart';
import 'package:music_player_frontend/core/ui/components/scaffolds/glass_animated_scaffold.dart';
import 'package:miniplayer/miniplayer.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:universal_platform/universal_platform.dart';

class MainScaffold extends StatefulWidget {
  static Route<dynamic> route() {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => const MainScaffold(),
      settings: const RouteSettings(name: "/main"),
    );
  }

  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  bool _didPushInitial = false;
  final FocusNode _shortcutFocusNode = FocusNode(
    debugLabel: 'main_scaffold_shortcuts',
  );

  @override
  void dispose() {
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  void _requestRefresh() {
    context.read<AbstractAppStateProvider>().requestRefresh();
  }

  Future<void> _handleBackPressed() async {
    final provider = context.watch<AbstractAppStateProvider>();
    final scaffoldState = provider.scaffoldKey.currentState;

    if (scaffoldState?.isEndDrawerOpen ?? false) {
      scaffoldState?.closeEndDrawer();
      return;
    }

    if (scaffoldState?.isDrawerOpen ?? false) {
      scaffoldState?.closeDrawer();
      return;
    }

    if (provider.isPanelOpen.value) {
      provider.miniPlayerController.animateToHeight(state: PanelState.min);
      return;
    }

    final innerNavigator = provider.innerNavigatorKey.currentState;
    if (innerNavigator != null && innerNavigator.canPop()) {
      innerNavigator.pop();
      return;
    }

    if (UniversalPlatform.isAndroid) {
      await SystemNavigator.pop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPushInitial) return;
    _didPushInitial = true;
    final appState = context.read<AbstractAppStateProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appState.innerNavigatorKey.currentState?.pushReplacement(
        HomeScreen.route(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Background colors are populated asynchronously from the active cover.
    // Subscribe so the mesh repaints as soon as extraction completes.
    final provider = context.watch<AbstractAppStateProvider>();

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    if (width < 200 || height < 200) {
      return Scaffold(
        body: Center(
          child: Text(
            "Your screen is too small to display the app. Please use a device with a larger screen.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      );
    }

    try {
      final isMobile = ResponsiveBreakpoints.of(context).isMobile;
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f5): _requestRefresh,
          const SingleActivator(LogicalKeyboardKey.keyR, control: true):
              _requestRefresh,
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
              _requestRefresh,
        },
        child: Focus(
          focusNode: _shortcutFocusNode,
          autofocus: true,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) {
              if ((event.buttons & kBackMouseButton) != 0) {
                _handleBackPressed();
              }
            },
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                await _handleBackPressed();
              },
              child: GlassAnimatedScaffold(
                scaffoldKey: provider.scaffoldKey,
                controller: provider.gradientController,
                colors: provider.colors,
                extendBody: true,
                extendBodyBehindAppBar: isMobile,
                appBar: AppBarWidget(),
                drawer: Drawer(
                  backgroundColor: Colors.transparent,
                  child:
                      isMobile
                          ? DrawerWidget(mobileDrawer: true)
                          : SizedBox.shrink(),
                ),
                endDrawer: provider.getEndDrawer(context),
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
              ),
            ),
          ),
        ),
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
      final inset = AppLayout.pageInset(width, mobile: true);
      return EdgeInsets.only(
        top: inset + MediaQuery.of(context).padding.top,
        left: inset,
        right: inset,
        bottom: inset + MediaQuery.of(context).padding.bottom,
      );
    }

    return AppLayout.mainScaffoldPadding(
      MediaQuery.sizeOf(context),
      mobile: false,
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
      final addedTopPadding = isMobile ? kToolbarHeight : 0.0;
      final width = MediaQuery.of(context).size.width;
      final height = MediaQuery.of(context).size.height;

      final navigatorWidget = Theme(
        data: MusicPlayerTheme.getTheme(),
        child: HeroControllerScope(
          controller: MaterialApp.createMaterialHeroController(),
          child: Navigator(
            key: provider.innerNavigatorKey,
            onGenerateRoute: (_) => HomeScreen.route(),
          ),
        ),
      );

      if (isMobile) {
        return Padding(
          padding: EdgeInsets.only(
            top: addedTopPadding,
            bottom: height * 0.075 + width * 0.02,
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
            SizedBox(width: AppLayout.contentGap(width)),
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
}
