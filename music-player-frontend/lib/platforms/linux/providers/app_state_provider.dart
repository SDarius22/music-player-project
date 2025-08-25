import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/providers/app_state_provider.dart';
import 'package:tray_manager/tray_manager.dart';

class AppStateProvider extends AbstractAppStateProvider with TrayListener{
  final AudioProvider audioProvider;
  final SettingsService settingsService;
  final navigatorKey = GlobalKey<NavigatorState>();
  bool isDarkMode = true;
  bool isDrawerOpen = false;
  List<String> appActions = [];

  MiniplayerController miniPlayerController = MiniplayerController();
  AnimatedMeshGradientController animatedMeshGradientController = AnimatedMeshGradientController();
  ScrollController itemScrollController = ScrollController();

  AppSettings appSettings = AppSettings();

  ValueNotifier<bool> isPanelOpen = ValueNotifier(false);

  Color lightColor = Colors.white;
  Color darkColor = Colors.black;
  ThemeData themeData = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.blueGrey,
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
  );


  AppStateProvider(this.audioProvider, this.settingsService) {
    trayManager.addListener(this);
    initTray();
    appSettings = settingsService.getAppSettings() ?? AppSettings();
    audioProvider.addListener(() async {
      debugPrint('AudioProvider changed, updating colors');
      setColors();
      setTheme();
    });
    audioProvider.playingNotifier.addListener(() {
      if (audioProvider.playingNotifier.value) {
        animatedMeshGradientController.start();
      } else {
        animatedMeshGradientController.stop();
      }
      initTray();
    });
  }

  Future<void> initTray() async {
    if (!appSettings.systemTray) {
      try{
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

    Menu menu =  Menu(
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

    trayManager.setIcon(Platform.isLinux ? 'assets/logo.png' : 'assets/logo.ico');
    trayManager.setTitle('Music Player${kDebugMode ? ' Debug' : ''}');
    trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() async {
    trayManager.popUpContextMenu();
  }

  Future<void> addAppAction(String action) async {
    if (!appActions.contains(action)) {
      appActions.add(action);
      notifyListeners();
    }
  }

  void updateAppSettings() {
    settingsService.updateAppSettings(appSettings);
    notifyListeners();
  }

  Future<void> setColors() async {
    debugPrint('Setting colors based on image, length: ${audioProvider.image?.length ?? 0}');
    var colors = await WorkerService.extractColors(audioProvider.image ?? Uint8List(0));
    lightColor = colors[0];
    darkColor = colors[1];
    debugPrint('Colors set: lightColor: $lightColor, darkColor: $darkColor');
  }

  Future<void> setTheme() async {
    final Color scaffoldBg = isDarkMode ? const Color(0xFF0E0E0E) : const Color(0xFFFFFFFF);
    final Color primaryColor = lightColor; // always use as primary
    final Color accentColor = darkColor;   // always use as secondary/accent

    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color invertedTextColor = isDarkMode ? Colors.black : Colors.white;

    themeData = ThemeData(
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBg,
      primaryColor: primaryColor,
      cardColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF6F6F6),

      colorScheme: ColorScheme(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        primary: primaryColor,
        onPrimary: invertedTextColor,
        secondary: accentColor,
        onSecondary: invertedTextColor,
        background: scaffoldBg,
        onBackground: textColor,
        surface: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF6F6F6),
        onSurface: textColor,
        error: Colors.red,
        onError: Colors.white,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: textColor,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textColor, fontSize: 18),
        bodyMedium: TextStyle(color: textColor, fontSize: 14),
        titleLarge: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
      ),

      iconTheme: IconThemeData(color: textColor),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: invertedTextColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );

    notifyListeners();
  }


  void setDrawerOpen(bool isOpen) {
    isDrawerOpen = isOpen;
    notifyListeners();
  }
}