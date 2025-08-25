import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/providers/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/worker_service.dart';
import 'package:music_player_frontend/utils/constants.dart';

abstract class AbstractAppStateProvider with ChangeNotifier {
  late final AbstractAudioProvider _audioProvider;
  late final SettingsService _settingsService;
  late AppSettings appSettings;
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool isDarkMode = true;
  bool isDrawerOpen = false;
  List<String> appActions = [];

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


  AbstractAppStateProvider(this._audioProvider, this._settingsService) {
    initTray();
    appSettings = _settingsService.getAppSettings();
    _audioProvider.addListener(() async {
      debugPrint('AudioProvider changed, updating colors');
      setColors();
      setTheme();
    });
    // _audioProvider.playingNotifier.addListener(() {
    //   if (_audioProvider.playingNotifier.value) {
    //     animatedMeshGradientController.start();
    //   } else {
    //     animatedMeshGradientController.stop();
    //   }
    //   initTray();
    // });
  }

  Future<void> initTray();

  Future<void> addAppAction(String action) async {
    if (!appActions.contains(action)) {
      appActions.add(action);
      notifyListeners();
    }
  }

  void updateAppSettings() {
    _settingsService.updateAppSettings(appSettings);
    notifyListeners();
  }

  Future<void> setColors() async {
    debugPrint('Setting colors based on image, length: ${_audioProvider.currentSong?.image?.length ?? 0}');
    var colors = await WorkerService.extractColors(_audioProvider.currentSong?.image ?? logoImage);
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