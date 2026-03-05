import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/screens/settings_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/platforms/macos/ui/screens/create_or_import_screen.dart';
import 'package:music_player_frontend/platforms/macos/ui/screens/library_settings.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends AbstractSettingsScreen {
  static Route<void> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SettingsScreen();
      },
    );
  }

  const SettingsScreen({super.key});

  @override
  AbstractSettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends AbstractSettingsScreenState<SettingsScreen> {
  @override
  List<Map<String, Widget>> get settingsMap {
    var height = MediaQuery.of(context).size.height;
    var normalSize = height * 0.02;
    var smallSize = height * 0.015;

    final appState = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    return [
      {
        "title": const Text("Library Settings"),
        "subtitle": const Text("Manage your music library settings"),
        "trailing": IconButton(
          onPressed: () {
            var appState = context.read<AbstractAppStateProvider>();
            appState.innerNavigatorKey.currentState?.push(
              LibrarySettings.route(abstractAppStateProvider: appState),
            );
          },
          icon: Icon(
            FluentIcons.right,
            color: Colors.white,
            size: MediaQuery.of(context).size.height * 0.03,
          ),
        ),
      },

      // Playback Speed
      {
        "title": Text(
          "Playback Speed",
          style: TextStyle(
            fontSize: normalSize,
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        "subtitle": Text(
          "Set the playback speed to a certain value",
          style: TextStyle(fontSize: smallSize, color: Colors.grey.shade300),
        ),
        "trailing": SizedBox(
          width: MediaQuery.of(context).size.width * 0.15,
          child: ValueListenableBuilder(
            valueListenable: audioProvider.playbackSpeedNotifier,
            builder: (context, value, child) {
              return SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbColor: Colors.white,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: height * 0.0075,
                  ),
                  showValueIndicator: ShowValueIndicator.onDrag,
                  activeTrackColor: MusicPlayerTheme.primaryPurple,
                  inactiveTrackColor: Colors.white,
                  valueIndicatorColor: Colors.white,
                  valueIndicatorTextStyle: TextStyle(
                    fontSize: smallSize,
                    color: Colors.black,
                  ),
                  valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                ),
                child: Slider(
                  min: 0.0,
                  max: 2.0,
                  divisions: 20,
                  label: "${value.toStringAsPrecision(2)}x",
                  mouseCursor: SystemMouseCursors.click,
                  value: value,
                  onChanged: (double value) {
                    audioProvider.setPlaybackSpeed(value);
                  },
                ),
              );
            },
          ),
        ),
      },

      // Close To System Tray
      {
        "title": Text(
          "Close To System Tray",
          style: TextStyle(
            fontSize: normalSize,
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        "subtitle": Text(
          "Choose whether the app should close to the system tray",
          style: TextStyle(fontSize: smallSize, color: Colors.grey.shade300),
        ),
        "trailing": Switch(
          value: !appState.appSettings.fullClose,
          onChanged: (value) {
            setState(() {
              appState.appSettings.fullClose = !value;
            });
          },
          trackColor: WidgetStateProperty.all(MusicPlayerTheme.primaryPurple),
          thumbColor: WidgetStateProperty.all(Colors.white),
          thumbIcon: WidgetStateProperty.all(
            !appState.appSettings.fullClose
                ? const Icon(Icons.check, color: Colors.black)
                : const Icon(Icons.close, color: Colors.black),
          ),
          activeThumbColor: Colors.white,
        ),
      },

      // Import Playlist
      {
        "title": Text(
          "Import Playlist",
          style: TextStyle(
            fontSize: normalSize,
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        "subtitle": Text(
          "Import a playlist from your library",
          style: TextStyle(fontSize: smallSize, color: Colors.grey.shade300),
        ),
        "trailing": IconButton(
          onPressed: () async {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              initialDirectory: appState.appSettings.mainSongPlace,
              type: FileType.custom,
              allowedExtensions: ['m3u'],
              allowMultiple: false,
            );
            if (result != null) {
              File file = File(result.files.single.path ?? "");
              List<String> lines = file.readAsLinesSync();
              String playlistName = file.path.split("/").last.split(".").first;
              lines.removeAt(0);
              for (int i = 0; i < lines.length; i++) {
                lines[i] = lines[i].split("/").last;
              }
              appState.innerNavigatorKey.currentState?.push(
                CreateOrImportScreen.route(
                  playlistName: playlistName,
                  playlistPaths: lines,
                  import: true,
                ),
              );
            }
          },
          icon: Icon(
            FluentIcons.open,
            color: Colors.white,
            size: height * 0.03,
          ),
        ),
      },

      // // Export Playlists
      // {
      //   "title": Text(
      //     "Export Playlists",
      //     style: TextStyle(
      //       fontSize: normalSize,
      //       fontWeight: FontWeight.normal,
      //       color: Colors.white,
      //     ),
      //   ),
      //   "subtitle": Text(
      //     "Export playlists to your library",
      //     style: TextStyle(fontSize: smallSize, color: Colors.grey.shade300),
      //   ),
      //   "trailing": IconButton(
      //     onPressed: () {
      //       appState.navigatorKey.currentState?.push(
      //         AddOrExportScreen.route(export: true),
      //       );
      //     },
      //     icon: Icon(
      //       FluentIcons.open,
      //       color: Colors.white,
      //       size: height * 0.03,
      //     ),
      //   ),
      // },
    ];
  }

  @override
  EdgeInsetsGeometry buildPadding(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    return EdgeInsets.symmetric(
      horizontal: width * 0.025,
      vertical: height * 0.025,
    );
  }
}
