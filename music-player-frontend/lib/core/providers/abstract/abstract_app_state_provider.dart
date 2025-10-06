import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';

abstract class AbstractAppStateProvider with ChangeNotifier {
  final AbstractAudioProvider audioProvider;
  final SettingsService settingsService;

  final navigatorKey = GlobalKey<NavigatorState>();
  final gradientController = AnimatedMeshGradientController();
  final miniPlayerController = MiniPlayerController();

  get appSettings => settingsService.currentAppSettings;

  bool isDarkMode = true;
  bool isDrawerOpen = false;
  List<String> appActions = [];

  ValueNotifier<bool> isPanelOpen = ValueNotifier(false);

  AbstractAppStateProvider(this.audioProvider, this.settingsService) {
    audioProvider.playingNotifier.addListener(() async {
      if (audioProvider.playingNotifier.value) {
        gradientController.start();
      } else {
        gradientController.stop();
      }
    });
  }

  Future<void> addAppAction(String action) async {
    if (!appActions.contains(action)) {
      appActions.add(action);
      notifyListeners();
    }
  }

  void updateAppSettings() {
    settingsService.updateAppSettings();
    notifyListeners();
  }

  void setDrawerOpen(bool isOpen) {
    isDrawerOpen = isOpen;
    notifyListeners();
  }

  //
  // Future<void> setColors() async {
  //   debugPrint(
  //     'Setting colors based on image, length: ${audioProvider.audioService.currentSong?.image?.length ?? 0}',
  //   );
  //   if (audioProvider.audioService.currentSong?.image == null) {
  //     lightColor = MusicPlayerTheme.primaryPurple;
  //     darkColor = MusicPlayerTheme.darkPurple;
  //     return;
  //   }
  //   var colors = await WorkerService.extractColors(
  //     audioProvider.audioService.currentSong?.image ?? logoImage,
  //   );
  //   lightColor = colors[0];
  //   darkColor = colors[1];
  //   debugPrint('Colors set: lightColor: $lightColor, darkColor: $darkColor');
  // }
}
