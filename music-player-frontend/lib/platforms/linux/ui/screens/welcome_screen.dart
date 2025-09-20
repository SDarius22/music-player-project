import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/app_state_provider.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/widgets/linux_top_bar_widget.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/loading_screen.dart';
import 'package:provider/provider.dart';

class WelcomeScreen extends StatefulWidget {
  static Route<dynamic> route() {
    return MaterialPageRoute(builder: (_) => const WelcomeScreen());
  }

  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late AbstractAppStateProvider abstractAppStateProvider;

  @override
  void initState() {
    super.initState();
    abstractAppStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    // var smallSize = height * 0.015;
    return Scaffold(
      appBar: const AppBarWidget(),
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
        child: Column(
          children: [
            SizedBox(height: height * 0.25),
            Text(
              "Welcome to Music Player!",
              style: TextStyle(
                fontSize: boldSize,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: height * 0.025),
            if (abstractAppStateProvider.appSettings.songPlaces.isEmpty)
              Text(
                "Add music to your library by choosing a folder below:",
                style: TextStyle(
                  fontSize: normalSize,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                ),
              ),
            if (abstractAppStateProvider.appSettings.songPlaces.isEmpty)
              SizedBox(height: height * 0.025),
            if (abstractAppStateProvider.appSettings.songPlaces.isEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: width * 0.1,
                height: height * 0.06,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(0),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.grey.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onPressed: () async {
                    String chosen =
                        await FilePicker.platform.getDirectoryPath() ?? "";
                    if (chosen != "") {
                      //debugPrint(chosen);
                      abstractAppStateProvider.appSettings.songPlaces = [
                        chosen,
                      ];
                      abstractAppStateProvider.appSettings.mainSongPlace =
                          chosen;
                      abstractAppStateProvider
                          .appSettings
                          .songPlaceIncludeSubfolders = [1];
                      setState(() {});
                    }
                  },
                  child: Icon(
                    FluentIcons.folder,
                    color: Colors.white,
                    size: height * 0.03,
                  ),
                ),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                child: DataTable(
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
                  rows: List<DataRow>.generate(
                    abstractAppStateProvider.appSettings.songPlaces.length + 1,
                    (index) {
                      return index <
                              abstractAppStateProvider
                                  .appSettings
                                  .songPlaces
                                  .length
                          ? DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  abstractAppStateProvider
                                      .appSettings
                                      .songPlaces[index],
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
                                    abstractAppStateProvider
                                                .appSettings
                                                .mainSongPlace ==
                                            abstractAppStateProvider
                                                .appSettings
                                                .songPlaces[index]
                                        ? FluentIcons.checkCircleOn
                                        : FluentIcons.checkCircleOff,
                                    color: Colors.white,
                                    size: height * 0.03,
                                  ),
                                  onPressed:
                                      abstractAppStateProvider
                                                  .appSettings
                                                  .songPlaces
                                                  .length <=
                                              1
                                          ? null
                                          : () {
                                            setState(() {
                                              abstractAppStateProvider
                                                      .appSettings
                                                      .mainSongPlace =
                                                  abstractAppStateProvider
                                                      .appSettings
                                                      .songPlaces[index];
                                            });
                                          },
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: Icon(
                                    abstractAppStateProvider
                                                .appSettings
                                                .songPlaceIncludeSubfolders[index] ==
                                            1
                                        ? FluentIcons.checkCircleOn
                                        : FluentIcons.checkCircleOff,
                                    color: Colors.white,
                                    size: height * 0.03,
                                  ),
                                  onPressed: () {
                                    if (abstractAppStateProvider
                                            .appSettings
                                            .songPlaceIncludeSubfolders[index] ==
                                        1) {
                                      debugPrint("Setting to 0");
                                      final updatedList = List<int>.from(
                                        abstractAppStateProvider
                                            .appSettings
                                            .songPlaceIncludeSubfolders,
                                      );
                                      updatedList[index] = 0;
                                      abstractAppStateProvider
                                              .appSettings
                                              .songPlaceIncludeSubfolders =
                                          updatedList;
                                    } else {
                                      debugPrint("Setting to 1");
                                      final updatedList = List<int>.from(
                                        abstractAppStateProvider
                                            .appSettings
                                            .songPlaceIncludeSubfolders,
                                      );
                                      updatedList[index] = 1;
                                      abstractAppStateProvider
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
                                        abstractAppStateProvider
                                            .appSettings
                                            .songPlaces[index];
                                    abstractAppStateProvider
                                        .appSettings
                                        .songPlaces = List<String>.from(
                                      abstractAppStateProvider
                                          .appSettings
                                          .songPlaces,
                                    )..removeAt(index);
                                    abstractAppStateProvider
                                            .appSettings
                                            .songPlaceIncludeSubfolders =
                                        List<int>.from(
                                          abstractAppStateProvider
                                              .appSettings
                                              .songPlaceIncludeSubfolders,
                                        )..removeAt(index);
                                    if (abstractAppStateProvider
                                            .appSettings
                                            .mainSongPlace ==
                                        current) {
                                      try {
                                        abstractAppStateProvider
                                                .appSettings
                                                .mainSongPlace =
                                            abstractAppStateProvider
                                                .appSettings
                                                .songPlaces[0];
                                      } catch (e) {
                                        abstractAppStateProvider
                                            .appSettings
                                            .mainSongPlace = "";
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
                                      abstractAppStateProvider
                                          .appSettings
                                          .songPlaces = List<String>.from(
                                        abstractAppStateProvider
                                            .appSettings
                                            .songPlaces,
                                      )..add(chosen);
                                      abstractAppStateProvider
                                              .appSettings
                                              .songPlaceIncludeSubfolders =
                                          List<int>.from(
                                            abstractAppStateProvider
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
                    },
                  ),
                ),
              ),
            SizedBox(height: height * 0.1),
            Container(
              width: width,
              padding: EdgeInsets.only(right: width * 0.075),
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(0),
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.grey.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                onPressed:
                    abstractAppStateProvider.appSettings.songPlaces.isEmpty
                        ? null
                        : () async {
                          debugPrint("Pressed");
                          abstractAppStateProvider.appSettings.firstTime =
                              false;
                          debugPrint(
                            abstractAppStateProvider.appSettings.firstTime
                                .toString(),
                          );
                          abstractAppStateProvider.updateAppSettings();
                          Navigator.push(context, LoadingScreen.route());
                        },
                child: Icon(
                  FluentIcons.forward,
                  color: Colors.white,
                  size: height * 0.03,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
