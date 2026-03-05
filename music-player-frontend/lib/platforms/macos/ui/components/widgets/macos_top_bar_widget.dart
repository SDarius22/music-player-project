import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/top_bar_widget.dart';
import 'package:provider/provider.dart';

class MacosAppBarWidget extends AbstractAppBarWidget {
  const MacosAppBarWidget({super.key, super.actions = const []});

  @override
  Widget buildAppBar(BuildContext context) {
    return WindowTitleBarBox(
      child: Selector<AbstractAppStateProvider, bool>(
        selector: (context, provider) => provider.isFullScreen,
        builder: (context, isFullScreen, child) {
          return Container(
            color:
                isFullScreen
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.4),
            child: MoveWindow(),
          );
        },
      ),
    );
  }
}
