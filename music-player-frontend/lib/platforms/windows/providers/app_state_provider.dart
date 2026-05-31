import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:tray_manager/tray_manager.dart';

class AppStateProvider extends AbstractAppStateProvider with TrayListener {
  static final _logger = Logger('WindowsAppStateProvider');

  AppStateProvider(
    super.audioProvider,
    super.healthService,
    super.settingsService,
  ) {
    trayManager.addListener(this);
    initTray();
  }

  Future<void> initTray() async {
    if (!appSettings.systemTray) {
      try {
        await trayManager.destroy();
      } catch (e) {
        _logger.warning('Error destroying tray', e);
      }
      return;
    }
    MenuItem menuItemPlay = MenuItem(
      key: 'play',
      label: audioProvider.playingNotifier.value ? 'Pause' : 'Play',
      onClick: (menuItem) {
        if (kDebugMode) {
          _logger.fine('click item play');
        }
        if (audioProvider.playingNotifier.value) {
          audioProvider.pause();
          menuItem.label = 'Play';
        } else {
          audioProvider.play();
          menuItem.label = 'Pause';
        }
      },
    );

    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'title',
          label: 'MP33r ${kDebugMode ? 'Debug' : ''}',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'previous',
          label: 'Previous',
          onClick: (menuItem) async {
            if (kDebugMode) {
              _logger.fine('click item previous');
            }
            await audioProvider.skipToPrevious();
          },
        ),
        menuItemPlay,
        MenuItem(
          key: 'next',
          label: 'Next',
          onClick: (menuItem) async {
            if (kDebugMode) {
              _logger.fine('click item next');
            }
            await audioProvider.skipToNext();
          },
        ),
        MenuItem.separator(),
        MenuItem.checkbox(
          key: 'repeat',
          label: 'Repeat',
          checked: false,
          onClick: (menuItem) {
            if (kDebugMode) {
              _logger.fine('click item repeat');
            }
            menuItem.checked = !(menuItem.checked == true);
            audioProvider.setRepeat(menuItem.checked == true);
          },
        ),
        MenuItem.checkbox(
          key: 'shuffle',
          label: 'Shuffle',
          checked: false,
          onClick: (menuItem) {
            if (kDebugMode) {
              _logger.fine('click item shuffle');
            }
            menuItem.checked = !(menuItem.checked == true);
            audioProvider.setShuffle(menuItem.checked == true);
          },
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'show',
          label: 'Show',
          onClick: (menuItem) {
            if (kDebugMode) {
              _logger.fine('click item show');
            }
            appWindow.show();
          },
        ),
        MenuItem(
          key: 'quit',
          label: 'Quit',
          onClick: (menuItem) {
            if (kDebugMode) {
              _logger.fine('click item quit');
            }
            appWindow.close();
          },
        ),
      ],
    );

    trayManager.setIcon('assets/logo.ico');
    trayManager.setTitle('MP33r${kDebugMode ? ' Debug' : ''}');
    trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() async {
    trayManager.popUpContextMenu();
  }
}
