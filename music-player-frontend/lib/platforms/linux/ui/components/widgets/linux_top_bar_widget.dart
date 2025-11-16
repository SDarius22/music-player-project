import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/widgets/top_bar_widget.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:provider/provider.dart';

class LinuxAppBarWidget extends AbstractAppBarWidget {
  const LinuxAppBarWidget({super.key, super.actions = const []});

  @override
  Widget buildAppBar(BuildContext context) {
    return WindowTitleBarBox(
      child: GlassContainer(
        color: Colors.black.withValues(alpha: 0.4),
        borderColor: Colors.transparent,
        blur: 45.0,
        borderWidth: 0.0,
        elevation: 3.0,
        shadowColor: Colors.black.withValues(alpha: 0.20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: MoveWindow(
                child: Container(
                  padding: const EdgeInsets.only(left: 10),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Music Player',
                    style:
                        MusicPlayerTheme.getTheme(
                          context,
                          context.read<Scaler>(),
                        ).textTheme.bodyLarge,
                  ),
                ),
              ),
            ),

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
              onPressed: () {
                var appStateProvider = context.read<AbstractAppStateProvider>();
                if (appStateProvider
                    .settingsService
                    .currentAppSettings
                    .fullClose) {
                  appWindow.close();
                } else {
                  appWindow.hide();
                }
              },
              colors: WindowButtonColors(
                normal: Colors.transparent,
                iconNormal: Colors.white,
                iconMouseOver: Colors.black,
                mouseOver: Colors.red,
                mouseDown: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
