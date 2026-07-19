import 'package:flutter/material.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/features/navigation/presentation/widgets/playback_drawer.dart';
import 'package:responsive_framework/responsive_framework.dart';

class AppStateProvider extends AbstractAppStateProvider {
  AppStateProvider(
    super.audioProvider,
    super.healthService,
    super.settingsService,
  );

  @override
  Widget? getEndDrawer(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      backgroundColor: Colors.transparent,
      width: !ResponsiveBreakpoints.of(context).isMobile ? width * 0.5 : null,
      child: PlaybackDrawer(),
    );
  }
}
