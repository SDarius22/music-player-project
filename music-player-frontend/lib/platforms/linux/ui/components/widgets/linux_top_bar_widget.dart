import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/top_bar_widget.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/theme.dart';
import 'package:provider/provider.dart';

class AppBarWidget extends AbstractAppBarWidget {
  const AppBarWidget({super.key, super.actions = const []});

  @override
  Widget buildAppBar(BuildContext context) {
    return WindowTitleBarBox(
      child: Container(
        color: Colors.black,
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
                        MusicPlayerTheme.getTheme(context).textTheme.bodyLarge,
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
