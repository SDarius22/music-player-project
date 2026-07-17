import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:tray_manager/tray_manager.dart';

/// Shared system-tray behavior for desktop application shells.
class DesktopAppStateProvider extends AbstractAppStateProvider
    with TrayListener {
  static final _logger = Logger('DesktopAppStateProvider');
  final String trayIcon;
  final bool setTrayTitle;

  DesktopAppStateProvider(
    super.audioProvider,
    super.healthService,
    super.settingsService, {
    required this.trayIcon,
    this.setTrayTitle = true,
  }) {
    trayManager.addListener(this);
    initTray();
  }

  Future<void> initTray() async {
    if (!appSettings.systemTray) {
      try {
        await trayManager.destroy();
      } catch (error) {
        _logger.warning('Error destroying tray', error);
      }
      return;
    }

    final playItem = MenuItem(
      key: 'play',
      label: audioProvider.playingNotifier.value ? 'Pause' : 'Play',
      onClick: (item) {
        if (audioProvider.playingNotifier.value) {
          audioProvider.pause();
          item.label = 'Play';
        } else {
          audioProvider.play();
          item.label = 'Pause';
        }
      },
    );
    final menu = Menu(
      items: [
        MenuItem(key: 'title', label: 'MP33r ${kDebugMode ? 'Debug' : ''}'),
        MenuItem.separator(),
        _action('previous', 'Previous', audioProvider.skipToPrevious),
        playItem,
        _action('next', 'Next', audioProvider.skipToNext),
        MenuItem.separator(),
        _toggle('repeat', 'Repeat', audioProvider.setRepeat),
        _toggle('shuffle', 'Shuffle', audioProvider.setShuffle),
        MenuItem.separator(),
        _action('show', 'Show', () async => appWindow.show()),
        _action('quit', 'Quit', () async => appWindow.close()),
      ],
    );
    await trayManager.setIcon(trayIcon);
    if (setTrayTitle) {
      await trayManager.setTitle('MP33r${kDebugMode ? ' Debug' : ''}');
    }
    await trayManager.setContextMenu(menu);
  }

  MenuItem _action(String key, String label, Future<void> Function() action) {
    return MenuItem(key: key, label: label, onClick: (_) async => action());
  }

  MenuItem _toggle(String key, String label, void Function(bool) update) {
    return MenuItem.checkbox(
      key: key,
      label: label,
      checked: false,
      onClick: (item) {
        item.checked = !(item.checked == true);
        update(item.checked == true);
      },
    );
  }

  @override
  void onTrayIconMouseDown() => trayManager.popUpContextMenu();
}
