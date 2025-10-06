import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:tray_manager/tray_manager.dart';

class AppStateProvider extends AbstractAppStateProvider with TrayListener {
  AppStateProvider(super.audioProvider, super.settingsService) {
    trayManager.addListener(this);
    initTray();
  }

  Future<void> initTray() async {
    if (!settingsService.currentAppSettings.systemTray) {
      try {
        await trayManager.destroy();
      } catch (e) {
        debugPrint('Error destroying tray: $e');
      }
      return;
    }
    MenuItem menuItemPlay = MenuItem(
      key: 'play',
      label: audioProvider.playingNotifier.value ? 'Pause' : 'Play',
      onClick: (menuItem) {
        if (kDebugMode) {
          print('click item play');
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
          label: 'Music Player ${kDebugMode ? 'Debug' : ''}',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'previous',
          label: 'Previous',
          onClick: (menuItem) async {
            if (kDebugMode) {
              print('click item previous');
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
              print('click item next');
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
              print('click item 1');
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
              print('click item 2');
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
              print('click item show');
            }
            appWindow.show();
          },
        ),
        MenuItem(
          key: 'quit',
          label: 'Quit',
          onClick: (menuItem) {
            if (kDebugMode) {
              print('click item quit');
            }
            appWindow.close();
          },
        ),
      ],
    );

    trayManager.setIcon(
      Platform.isLinux ? 'assets/logo.png' : 'assets/logo.ico',
    );
    trayManager.setTitle('Music Player${kDebugMode ? ' Debug' : ''}');
    trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() async {
    trayManager.popUpContextMenu();
  }
}
