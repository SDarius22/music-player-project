import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class LibrarySettings extends StatefulWidget {
  static Route<dynamic> route({bool backButton = true}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return LibrarySettings(backButton: backButton);
      },
    );
  }

  final bool backButton;

  const LibrarySettings({super.key, required this.backButton});

  @override
  State<LibrarySettings> createState() => _LibrarySettingsState();
}

class _LibrarySettingsState extends State<LibrarySettings> {
  @override
  Widget build(BuildContext context) {
    var abstractAppStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: true,
    );
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    double normalSize = height * 0.025;
    return GlassScaffold(
      body: Padding(
        padding: EdgeInsets.only(bottom: height * 0.01),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: height * 0.065,
              width: width,
              padding: EdgeInsets.symmetric(horizontal: width * 0.01),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.backButton)
                    IconButton(
                      onPressed: () {
                        debugPrint("Back");
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        FluentIcons.back,
                        size: height * 0.02,
                        color: Colors.white,
                      ),
                    ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                              borderRadius: BorderRadius.circular(
                                MediaQuery.of(context).size.height * 0.015,
                              ),
                            ),
                          ),
                          onPressed: () async {
                            String chosen =
                                await FilePicker.platform.getDirectoryPath() ??
                                "";
                            if (chosen != "") {
                              //debugPrint(chosen);
                              abstractAppStateProvider
                                  .appSettings
                                  .songPlaces = [chosen];
                              abstractAppStateProvider
                                  .appSettings
                                  .mainSongPlace = chosen;
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
                            abstractAppStateProvider
                                    .appSettings
                                    .songPlaces
                                    .length +
                                1,
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
                                              final updatedList = List<
                                                int
                                              >.from(
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
                                              final updatedList = List<
                                                int
                                              >.from(
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
                                                      .songPlaces =
                                                  List<String>.from(
                                                    abstractAppStateProvider
                                                        .appSettings
                                                        .songPlaces,
                                                  )..add(chosen);
                                              abstractAppStateProvider
                                                  .appSettings
                                                  .songPlaceIncludeSubfolders = List<
                                                int
                                              >.from(
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
