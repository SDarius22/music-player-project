import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fullscreen/flutter_fullscreen.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:fluenticons/fluenticons.dart';
import 'package:glass_kit/glass_container.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:universal_platform/universal_platform.dart';

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  const AppBarWidget({super.key});

  Widget buildAppBar(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    return ValueListenableBuilder(
      valueListenable: context.read<AbstractAppStateProvider>().opacityNotifier,
      builder: (context, appBarOpacity, child) {
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: !isMobile ? 1.0 : appBarOpacity,
          child: GlassContainer(
            height: MediaQuery.of(context).padding.top + kToolbarHeight,
            width: width,
            color: Colors.black.withValues(alpha: 0.4),
            borderColor: Colors.transparent,
            blur: 45.0,
            borderWidth: 0.0,
            elevation: 0.0,
            alignment: Alignment.center,
            child: SafeArea(child: buildContent(context)),
          ),
        );
      },
    );
  }

  Widget buildContent(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: width * 0.025),
        if (isMobile)
          IconButton(
            onPressed: () {
              final provider = context.read<AbstractAppStateProvider>();
              debugPrint("Menu button pressed");
              debugPrint(
                "Drawer is ${provider.scaffoldKey.currentState?.isDrawerOpen == true ? "open" : "closed"}",
              );
              if (provider.scaffoldKey.currentState?.isDrawerOpen ?? false) {
                provider.scaffoldKey.currentState?.closeDrawer();
              } else {
                provider.scaffoldKey.currentState?.openDrawer();
              }
            },
            icon: Icon(FluentIcons.menu, size: 24, color: Colors.white),
          ),
        if (UniversalPlatform.isDesktop && !isMobile) ...[
          Expanded(
            child: MoveWindow(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'MP33r',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  ValueListenableBuilder(
                    valueListenable:
                        context
                            .read<AbstractAppStateProvider>()
                            .connectivityStatusNotifier,
                    builder: (context, connectivityStatus, child) {
                      return connectivityStatus;
                    },
                  ),
                  SizedBox(width: width * 0.025),
                  if (!(UniversalPlatform.isMacOS &&
                      FullScreen.isFullScreen)) ...[
                    MinimizeWindowButton(
                      animate: true,
                      colors: WindowButtonColors(
                        normal: Colors.transparent,
                        iconNormal: Colors.white,
                        iconMouseOver: Colors.black,
                        mouseOver: Colors.grey,
                        mouseDown: Colors.grey,
                      ),
                    ),
                    appWindow.isMaximized
                        ? RestoreWindowButton(
                          animate: true,
                          colors: WindowButtonColors(
                            normal: Colors.transparent,
                            iconNormal: Colors.white,
                            iconMouseOver: Colors.black,
                            mouseOver: Colors.grey,
                            mouseDown: Colors.grey,
                          ),
                        )
                        : MaximizeWindowButton(
                          animate: true,
                          colors: WindowButtonColors(
                            normal: Colors.transparent,
                            iconNormal: Colors.white,
                            iconMouseOver: Colors.black,
                            mouseOver: Colors.grey,
                            mouseDown: Colors.grey,
                          ),
                        ),
                    CloseWindowButton(
                      animate: true,
                      colors: WindowButtonColors(
                        normal: Colors.transparent,
                        iconNormal: Colors.white,
                        iconMouseOver: Colors.redAccent,
                        mouseOver: Colors.redAccent.withValues(alpha: 0.8),
                        mouseDown: Colors.redAccent.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ] else ...[
          Text(
            'MP33r',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (UniversalPlatform.isWeb) ...[
            TextButton.icon(
              onPressed: () {
                context
                    .read<AbstractAppStateProvider>()
                    .scaffoldKey
                    .currentState
                    ?.openEndDrawer();
              },
              icon: Icon(FluentIcons.download, size: 24, color: Colors.white),
              label: Text(
                "Download App",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Colors.white),
              ),
            ),
          ] else ...[
            ValueListenableBuilder(
              valueListenable:
                  context
                      .read<AbstractAppStateProvider>()
                      .connectivityStatusNotifier,
              builder: (context, connectivityStatus, child) {
                return connectivityStatus;
              },
            ),
            SizedBox(width: width * 0.025),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildAppBar(context);
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
