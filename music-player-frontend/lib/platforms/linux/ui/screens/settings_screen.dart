import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/app_state_provider.dart';
import 'package:music_player_frontend/platforms/linux/providers/app_state_provider.dart';
import 'package:music_player_frontend/platforms/linux/providers/audio_provider.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/create_or_import_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/loading_screen.dart';
import 'package:music_player_frontend/utils/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  static Route<void> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/settings'),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SettingsScreen();
      },
    );
  }

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String dropDownValue = "Off";

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    //var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    var smallSize = height * 0.015;
    return Scaffold(
      body: Container(
        width: width,
        height: height,
        padding: EdgeInsets.only(
          top: height * 0.02,
          left: width * 0.01,
          right: width * 0.01,
          bottom: height * 0.02,
        ),
        alignment: Alignment.center,
        child: Consumer<AbstractAppStateProvider>(
          builder: (_, appState, __) {
            return Container(
              width: width * 0.85,
              padding: EdgeInsets.only(
                top: height * 0.05,
                bottom: height * 0.125,
              ),
              alignment: Alignment.center,
              child: ListView(
                padding: EdgeInsets.only(
                  bottom: height * 0.05,
                  right: width * 0.01,
                ),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Library Settings",
                        style: TextStyle(
                          fontSize: smallSize,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(height: height * 0.01),
                      Container(height: 1, color: Colors.grey.shade400),
                      SizedBox(height: height * 0.01),
                    ],
                  ),

                  ///Music Directory
                  DataTable(
                    columns: [
                      DataColumn(
                        label: Text(
                          "Folder",
                          style: TextStyle(
                            fontSize: normalSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "Main",
                          style: TextStyle(
                            fontSize: normalSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,
                        label: Text(
                          "Include subfolders",
                          style: TextStyle(
                            fontSize: normalSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "",
                          style: TextStyle(
                            fontSize: normalSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    rows: List<
                      DataRow
                    >.generate(appState.appSettings.songPlaces.length + 1, (
                      index,
                    ) {
                      return index < appState.appSettings.songPlaces.length
                          ? DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  appState.appSettings.songPlaces[index],
                                  style: TextStyle(
                                    fontSize: normalSize,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: Icon(
                                    appState.appSettings.mainSongPlace ==
                                            appState
                                                .appSettings
                                                .songPlaces[index]
                                        ? FluentIcons.checkCircleOn
                                        : FluentIcons.checkCircleOff,
                                    color: Colors.white,
                                    size: height * 0.03,
                                  ),
                                  onPressed:
                                      appState.appSettings.songPlaces.length <=
                                              1
                                          ? null
                                          : () {
                                            setState(() {
                                              appState
                                                  .appSettings
                                                  .mainSongPlace = appState
                                                      .appSettings
                                                      .songPlaces[index];
                                            });
                                          },
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: Icon(
                                    appState
                                                .appSettings
                                                .songPlaceIncludeSubfolders[index] ==
                                            1
                                        ? FluentIcons.checkCircleOn
                                        : FluentIcons.checkCircleOff,
                                    color: Colors.white,
                                    size: height * 0.03,
                                  ),
                                  onPressed: () {
                                    if (appState
                                            .appSettings
                                            .songPlaceIncludeSubfolders[index] ==
                                        1) {
                                      debugPrint("Setting to 0");
                                      final updatedList = List<int>.from(
                                        appState
                                            .appSettings
                                            .songPlaceIncludeSubfolders,
                                      );
                                      updatedList[index] = 0;
                                      appState
                                              .appSettings
                                              .songPlaceIncludeSubfolders =
                                          updatedList;
                                    } else {
                                      debugPrint("Setting to 1");
                                      final updatedList = List<int>.from(
                                        appState
                                            .appSettings
                                            .songPlaceIncludeSubfolders,
                                      );
                                      updatedList[index] = 1;
                                      appState
                                              .appSettings
                                              .songPlaceIncludeSubfolders =
                                          updatedList;
                                    }
                                    setState(() {});
                                  },
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: Icon(
                                    FluentIcons.trash,
                                    color: Colors.red,
                                    size: height * 0.03,
                                  ),
                                  onPressed: () {
                                    String current =
                                        appState.appSettings.songPlaces[index];
                                    appState
                                        .appSettings
                                        .songPlaces = List<String>.from(
                                      appState.appSettings.songPlaces,
                                    )..removeAt(index);
                                    appState
                                            .appSettings
                                            .songPlaceIncludeSubfolders =
                                        List<int>.from(
                                          appState
                                              .appSettings
                                              .songPlaceIncludeSubfolders,
                                        )..removeAt(index);
                                    if (appState.appSettings.mainSongPlace ==
                                        current) {
                                      try {
                                        appState.appSettings.mainSongPlace =
                                            appState.appSettings.songPlaces[0];
                                      } catch (e) {
                                        appState.appSettings.mainSongPlace = "";
                                      }
                                    }
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          )
                          : DataRow(
                            cells: [
                              const DataCell(Text("")),
                              const DataCell(Text("")),
                              const DataCell(Text("")),
                              DataCell(
                                IconButton(
                                  onPressed: () async {
                                    String chosen =
                                        await FilePicker.platform
                                            .getDirectoryPath() ??
                                        "";
                                    if (chosen != "") {
                                      //debugPrint(chosen);
                                      appState
                                          .appSettings
                                          .songPlaces = List<String>.from(
                                        appState.appSettings.songPlaces,
                                      )..add(chosen);
                                      appState
                                              .appSettings
                                              .songPlaceIncludeSubfolders =
                                          List<int>.from(
                                            appState
                                                .appSettings
                                                .songPlaceIncludeSubfolders,
                                          )..add(1);
                                      setState(() {});
                                    }
                                  },
                                  tooltip: "Add Another Folder",
                                  icon: Icon(
                                    FluentIcons.folderAdd,
                                    color: Colors.white,
                                    size: height * 0.03,
                                  ),
                                ),
                              ),
                            ],
                          );
                    }),
                  ),
                  Row(
                    children: [
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () async {
                          ///TODO - Find out why the fuck this isnt working
                          //appState.resetAudioSettings();
                          appState.updateAppSettings();
                          Navigator.of(
                            context,
                            rootNavigator: true,
                          ).pushReplacement(LoadingScreen.route());
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: width * 0.02,
                            vertical: height * 0.01,
                          ),
                        ),
                        child: Text(
                          "Save changes",
                          style: TextStyle(
                            fontSize: normalSize,
                            fontWeight: FontWeight.normal,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.02),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Playback Settings",
                        style: TextStyle(
                          fontSize: smallSize,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(height: height * 0.01),
                      Container(height: 1, color: Colors.grey.shade400),
                      SizedBox(height: height * 0.01),
                    ],
                  ),

                  ///Playback Speed
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Playback Speed",
                            style: TextStyle(
                              fontSize: normalSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: height * 0.005),
                          Text(
                            "Set the playback speed to a certain value",
                            style: TextStyle(
                              fontSize: smallSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ValueListenableBuilder(
                        valueListenable:
                            Provider.of<AudioProvider>(
                              context,
                              listen: false,
                            ).playbackSpeedNotifier,
                        builder: (context, value, child) {
                          return SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbColor: Colors.white,
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: height * 0.0075,
                              ),
                              showValueIndicator: ShowValueIndicator.always,
                              activeTrackColor: appState.lightColor,
                              inactiveTrackColor: Colors.white,
                              valueIndicatorColor: Colors.white,
                              valueIndicatorTextStyle: TextStyle(
                                fontSize: smallSize,
                                color: Colors.black,
                              ),
                              valueIndicatorShape:
                                  const PaddleSliderValueIndicatorShape(),
                            ),
                            child: Slider(
                              min: 0.0,
                              max: 2.0,
                              divisions: 20,
                              label: "${value.toStringAsPrecision(2)}x",
                              mouseCursor: SystemMouseCursors.click,
                              value: value,
                              onChanged: (double value) {
                                var audioProvider = Provider.of<AudioProvider>(
                                  context,
                                  listen: false,
                                );
                                audioProvider.setPlaybackSpeed(value);
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.02),

                  ///Playback Balance
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Playback Balance",
                            style: TextStyle(
                              fontSize: normalSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: height * 0.005),
                          Text(
                            "Set the playback balance to a certain value",
                            style: TextStyle(
                              fontSize: smallSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ValueListenableBuilder(
                        valueListenable:
                            Provider.of<AudioProvider>(
                              context,
                              listen: false,
                            ).balanceNotifier,
                        builder: (context, value, child) {
                          return SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbColor: Colors.white,
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: height * 0.0075,
                              ),
                              showValueIndicator: ShowValueIndicator.always,
                              activeTrackColor: appState.lightColor,
                              inactiveTrackColor: Colors.white,
                              valueIndicatorColor: Colors.white,
                              valueIndicatorTextStyle: TextStyle(
                                fontSize: smallSize,
                                color: Colors.black,
                              ),
                              valueIndicatorShape:
                                  const PaddleSliderValueIndicatorShape(),
                            ),
                            child: Slider(
                              min: -1.0,
                              max: 1.0,
                              divisions: 10,
                              mouseCursor: SystemMouseCursors.click,
                              value: value,
                              label:
                                  value < 0
                                      ? "Left : ${value.toStringAsPrecision(2)}"
                                      : value > 0
                                      ? "Right : ${value.toStringAsPrecision(2)}"
                                      : "Center",
                              onChanged: (double value) {
                                var audioProvider = Provider.of<AudioProvider>(
                                  context,
                                  listen: false,
                                );
                                audioProvider.setBalance(value);
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.02),

                  ///Timer
                  // Row(
                  //   children: [
                  //     Column(
                  //       crossAxisAlignment: CrossAxisAlignment.start,
                  //       mainAxisAlignment: MainAxisAlignment.center,
                  //       children: [
                  //         Text(
                  //           "Timer",
                  //           style: TextStyle(
                  //             fontSize: normalSize,
                  //             fontWeight: FontWeight.normal,
                  //             color: Colors.white,
                  //           ),
                  //         ),
                  //         SizedBox(
                  //           height: height * 0.005,
                  //         ),
                  //         Text("Set a timer to stop playback after a certain amount of time", style: TextStyle(
                  //           fontSize: smallSize,
                  //           fontWeight: FontWeight.normal,
                  //           color: Colors.grey.shade50,
                  //         ),),
                  //       ],
                  //     ),
                  //     const Spacer(),
                  //     ValueListenableBuilder(
                  //         valueListenable: appSettings.sleepTimerNotifier,
                  //         builder: (context, value, child){
                  //           String timer = value == 0 ? "Off" : value == 1 ? "1 minute" : value == 15 ? "15 minutes" : value == 30 ? "30 minutes" : value == 45 ? "45 minutes" : value == 60 ? "1 hour" : value == 120 ? "2 hours" : value == 180 ? "3 hours" : "4 hours";
                  //           return DropdownButton<String>(
                  //               value: timer,
                  //               icon: Icon(
                  //                 FluentIcons.down,
                  //                 color: Colors.white,
                  //                 size: height * 0.025,
                  //               ),
                  //               style: TextStyle(
                  //                 fontSize: normalSize,
                  //                 fontWeight: FontWeight.normal,
                  //                 color: Colors.white,
                  //               ),
                  //               underline: Container(
                  //                 height: 0,
                  //               ),
                  //               borderRadius: BorderRadius.circular(width * 0.01),
                  //               padding: EdgeInsets.zero,
                  //               alignment: Alignment.center,
                  //               items: const [
                  //                 DropdownMenuItem(
                  //                   value: 'Off',
                  //                   child: Text("Off"),
                  //                 ),
                  //                 DropdownMenuItem(
                  //                   value: '1 minute',
                  //                   child: Text("1 minute"),
                  //                 ),
                  //                 DropdownMenuItem(
                  //                   value: '15 minutes',
                  //                   child: Text("15 minutes"),
                  //                 ),
                  //                 DropdownMenuItem(
                  //                   value: '30 minutes',
                  //                   child: Text("30 minutes"),
                  //                 ),
                  //                 DropdownMenuItem(
                  //                   value: '45 minutes',
                  //                   child: Text("45 minutes"),
                  //                 ),
                  //                 DropdownMenuItem(
                  //                   value: '1 hour',
                  //                   child: Text("1 hour"),
                  //                 ),
                  //                 DropdownMenuItem(
                  //                   value: '2 hours',
                  //                   child: Text("2 hours"),
                  //                 ),
                  //                 DropdownMenuItem(
                  //                   value: '3 hours',
                  //                   child: Text("3 hours"),
                  //                 ),
                  //                 DropdownMenuItem(
                  //                   value: '4 hours',
                  //                   child: Text("4 hours"),
                  //                 ),
                  //               ],
                  //               onChanged: (String? newValue){
                  //                 // final apc = AudioPlayerController();
                  //                 // apc.setTimer(newValue ?? "Off");
                  //               }
                  //           );
                  //         }
                  //     ),
                  //
                  //   ],
                  // ),
                  // SizedBox(
                  //   height: height * 0.025,
                  // ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Application Settings",
                        style: TextStyle(
                          fontSize: smallSize,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(height: height * 0.01),
                      Container(height: 1, color: Colors.grey.shade400),
                      SizedBox(height: height * 0.01),
                    ],
                  ),

                  ///System Tray
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "System Tray",
                            style: TextStyle(
                              fontSize: normalSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: height * 0.005),
                          Text(
                            "Show the app in the system tray",
                            style: TextStyle(
                              fontSize: smallSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Switch(
                        value: appState.appSettings.systemTray,
                        onChanged: (value) {
                          setState(() {
                            appState.appSettings.systemTray = value;
                          });
                          (appState as AppStateProvider).initTray();
                        },
                        trackColor: WidgetStateProperty.all(
                          appState.lightColor,
                        ),
                        thumbColor: WidgetStateProperty.all(Colors.white),
                        thumbIcon: WidgetStateProperty.all(
                          appState.appSettings.systemTray
                              ? const Icon(Icons.check, color: Colors.black)
                              : const Icon(Icons.close, color: Colors.black),
                        ),
                        activeColor: Colors.white,
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.02),

                  ///Close to System Tray
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Close To System Tray",
                            style: TextStyle(
                              fontSize: normalSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: height * 0.005),
                          Text(
                            "Choose whether the app should close to the system tray",
                            style: TextStyle(
                              fontSize: smallSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Switch(
                        value: !appState.appSettings.fullClose,
                        onChanged: (value) {
                          setState(() {
                            appState.appSettings.fullClose = !value;
                          });
                        },
                        trackColor: WidgetStateProperty.all(
                          appState.lightColor,
                        ),
                        thumbColor: WidgetStateProperty.all(Colors.white),
                        thumbIcon: WidgetStateProperty.all(
                          !appState.appSettings.fullClose
                              ? const Icon(Icons.check, color: Colors.black)
                              : const Icon(Icons.close, color: Colors.black),
                        ),
                        activeColor: Colors.white,
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.02),

                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Dark Mode",
                            style: TextStyle(
                              fontSize: normalSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: height * 0.005),
                          Text(
                            "Choose the theme of the app",
                            style: TextStyle(
                              fontSize: smallSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Switch(
                        value: appState.isDarkMode,
                        onChanged: (value) {
                          setState(() {
                            appState.isDarkMode = value;
                            appState.setTheme();
                          });
                          (appState as AppStateProvider).initTray();
                        },
                        trackColor: WidgetStateProperty.all(
                          appState.lightColor,
                        ),
                        thumbColor: WidgetStateProperty.all(Colors.white),
                        thumbIcon: WidgetStateProperty.all(
                          appState.isDarkMode
                              ? const Icon(Icons.check, color: Colors.black)
                              : const Icon(Icons.close, color: Colors.black),
                        ),
                        activeColor: Colors.white,
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.02),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Playlist Settings",
                        style: TextStyle(
                          fontSize: smallSize,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(height: height * 0.01),
                      Container(height: 1, color: Colors.grey.shade400),
                      SizedBox(height: height * 0.01),
                    ],
                  ),

                  ///Import Playlists
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Import Playlist",
                            style: TextStyle(
                              fontSize: normalSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: height * 0.005),
                          Text(
                            "Import a playlist from your library",
                            style: TextStyle(
                              fontSize: smallSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () async {
                          FilePickerResult? result = await FilePicker.platform
                              .pickFiles(
                                initialDirectory:
                                    appState.appSettings.mainSongPlace,
                                type: FileType.custom,
                                allowedExtensions: ['m3u'],
                                allowMultiple: false,
                              );
                          if (result != null) {
                            File file = File(result.files.single.path ?? "");
                            List<String> lines = file.readAsLinesSync();
                            String playlistName =
                                file.path.split("/").last.split(".").first;
                            lines.removeAt(0);
                            for (int i = 0; i < lines.length; i++) {
                              lines[i] = lines[i].split("/").last;
                            }
                            appState.navigatorKey.currentState?.push(
                              CreateOrImportScreen.route(
                                playlistName: playlistName,
                                playlistPaths: lines,
                                import: true,
                              ),
                            );
                            // Navigator.pushNamed(context, '/create', arguments: [playlistName] + lines);
                          }
                        },
                        icon: Icon(
                          FluentIcons.open,
                          color: Colors.white,
                          size: height * 0.03,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.02),

                  ///Export Playlists
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Export Playlists",
                            style: TextStyle(
                              fontSize: normalSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: height * 0.005),
                          Text(
                            "Export playlists to your library",
                            style: TextStyle(
                              fontSize: smallSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          appState.navigatorKey.currentState?.push(
                            AddOrExportScreen.route(export: true),
                          );
                        },
                        icon: Icon(
                          FluentIcons.open,
                          color: Colors.white,
                          size: height * 0.03,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.02),

                  ///Possible more settings:
                  ///Crossfade between songs -> not sure if this is possible
                  ///Theme settings - maybe in the future
                  // Row(
                  //   children: [
                  //     Column(
                  //       crossAxisAlignment: CrossAxisAlignment.start,
                  //       mainAxisAlignment: MainAxisAlignment.center,
                  //       children: [
                  //         Text(
                  //           "Theme Settings",
                  //           style: TextStyle(
                  //             fontSize: normalSize,
                  //             fontWeight: FontWeight.normal,
                  //             color: Colors.white,
                  //           ),
                  //         ),
                  //         SizedBox(
                  //           height: height * 0.005,
                  //         ),
                  //         Text("Choose between light and dark theme", style: TextStyle(
                  //           fontSize: smallSize,
                  //           fontWeight: FontWeight.normal,
                  //           color: Colors.grey.shade50,
                  //         ),),
                  //       ],
                  //     ),
                  //     const Spacer(),
                  //     Switch(
                  //       value: SettingsController.settings.theme,
                  //       onChanged: (value){
                  //         setState(() {
                  //           SettingsController.settings.theme = value;
                  //           SettingsController.themeNotifier.value = value;
                  //         });
                  //
                  //         SettingsController.settingsBox.put(SettingsController.settings);
                  //       },
                  //       trackColor: WidgetStateProperty.all(SettingsController.colorNotifier2.value),
                  //       thumbColor: WidgetStateProperty.all(Colors.white),
                  //       thumbIcon: WidgetStateProperty.all(SettingsController.settings.theme ? const Icon(Icons.sunny, color: Colors.black,) : const Icon(Icons.nightlight, color: Colors.black,)),
                  //       activeColor: Colors.white,
                  //     ),
                  //
                  //
                  //   ],
                  // ),
                  // SizedBox(
                  //   height: height * 0.01,
                  // ),
                  // Container(
                  //   height: 1,
                  //   color: Colors.grey.shade600,
                  // ),
                  // SizedBox(
                  //   height: height * 0.01,
                  // ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
