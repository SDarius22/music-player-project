import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:musicplayer/components/app_top_bar.dart';
import 'package:musicplayer/providers/app_state_provider.dart';
import 'package:musicplayer/screens/loading_screen.dart';
import 'package:musicplayer/utils/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class WelcomeScreen extends StatefulWidget {
  static Route<dynamic> route() {
    return MaterialPageRoute(
      builder: (_) => const WelcomeScreen(),
    );
  }

  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late AppStateProvider appStateProvider;

  @override
  void initState() {
    super.initState();
    appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    // var smallSize = height * 0.015;
    return Scaffold(
      appBar: AppBarWidget(),
      body: Container(
        width: width,
        height: height,
        padding: EdgeInsets.only(
            top: height * 0.02,
            left: width * 0.01,
            right: width * 0.01,
            bottom: height * 0.02
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            SizedBox(
              height: height * 0.25,
            ),
            Text(
              "Welcome to Music Player!",
              style: TextStyle(
                fontSize: boldSize,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              height: height * 0.025,
            ),
            if (appStateProvider.appSettings.songPlaces.isEmpty)
            Text(
              "Add music to your library by choosing a folder below:",
              style: TextStyle(
                fontSize: normalSize,
                fontWeight: FontWeight.normal,
                color: Colors.white,
              ),
            ),
            if (appStateProvider.appSettings.songPlaces.isEmpty)
            SizedBox(
              height: height * 0.025,
            ),
            if (appStateProvider.appSettings.songPlaces.isEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: width * 0.1,
                height: height * 0.06,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(0),
                    foregroundColor: Colors.white, backgroundColor: Colors.grey.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onPressed: () async {
                    String chosen = await FilePicker.platform.getDirectoryPath() ?? "";
                    if(chosen != "") {
                      //debugPrint(chosen);
                      appStateProvider.appSettings.songPlaces = [chosen];
                      appStateProvider.appSettings.mainSongPlace = chosen;
                      appStateProvider.appSettings.songPlaceIncludeSubfolders = [1];
                      setState(() {
                      });
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
                      appStateProvider.appSettings.songPlaces.length + 1,
                    (index) {
                      return index < appStateProvider.appSettings.songPlaces.length?
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              appStateProvider.appSettings.songPlaces[index],
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
                                appStateProvider.appSettings.mainSongPlace ==
                                    appStateProvider.appSettings.songPlaces[index]
                                    ? FluentIcons.checkCircleOn
                                    : FluentIcons.checkCircleOff,
                                color: Colors.white,
                                size: height * 0.03,
                              ),
                              onPressed: appStateProvider.appSettings.songPlaces.length <= 1 ? null : () {
                                setState(() {
                                  appStateProvider.appSettings.mainSongPlace =
                                  appStateProvider.appSettings.songPlaces[index];
                                });
                              },
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: Icon(
                                appStateProvider.appSettings.songPlaceIncludeSubfolders[index] == 1
                                    ? FluentIcons.checkCircleOn
                                    : FluentIcons.checkCircleOff,
                                color: Colors.white,
                                size: height * 0.03,
                              ),
                              onPressed: () {
                                if (appStateProvider.appSettings.songPlaceIncludeSubfolders[index] == 1) {
                                  debugPrint("Setting to 0");
                                  final updatedList = List<int>.from(
                                      appStateProvider.appSettings.songPlaceIncludeSubfolders);
                                  updatedList[index] = 0;
                                  appStateProvider.appSettings.songPlaceIncludeSubfolders = updatedList;
                                } else {
                                  debugPrint("Setting to 1");
                                  final updatedList = List<int>.from(
                                      appStateProvider.appSettings.songPlaceIncludeSubfolders);
                                  updatedList[index] = 1;
                                  appStateProvider.appSettings.songPlaceIncludeSubfolders = updatedList;
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
                                String current = appStateProvider.appSettings.songPlaces[index];
                                appStateProvider.appSettings.songPlaces = List<String>.from(appStateProvider.appSettings.songPlaces)..removeAt(index);
                                appStateProvider.appSettings.songPlaceIncludeSubfolders = List<int>.from(appStateProvider.appSettings.songPlaceIncludeSubfolders)..removeAt(index);
                                if (appStateProvider.appSettings.mainSongPlace == current) {
                                  try {
                                    appStateProvider.appSettings.mainSongPlace = appStateProvider.appSettings.songPlaces[0];
                                  } catch (e) {
                                    appStateProvider.appSettings.mainSongPlace = "";
                                  }
                                }
                                setState(() {
                                });
                              },
                            ),
                          ),
                        ],
                      ) :
                      DataRow(
                        cells: [
                          const DataCell(
                            Text("")
                          ),
                          const DataCell(
                            Text("")
                          ),
                          const DataCell(
                            Text("")
                          ),
                          DataCell(
                            IconButton(
                              onPressed: () async {
                                String chosen = await FilePicker.platform.getDirectoryPath() ?? "";
                                if(chosen != "") {
                                  //debugPrint(chosen);
                                  appStateProvider.appSettings.songPlaces = List<String>.from(appStateProvider.appSettings.songPlaces)..add(chosen);
                                  appStateProvider.appSettings.songPlaceIncludeSubfolders = List<int>.from(appStateProvider.appSettings.songPlaceIncludeSubfolders)..add(1);
                                  setState(() {
                                  });
                                }
                              },
                              tooltip: "Add Another Folder",
                              icon: Icon(FluentIcons.folderAdd, color: Colors.white, size: height * 0.03,),
                            ),
                          ),
                        ],
                      );
                    }
                  ),
                ),
              ),
            SizedBox(
              height: height * 0.1,
            ),
            Container(
              width: width,
              padding: EdgeInsets.only(
                right: width * 0.075,
              ),
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(0),
                  foregroundColor: Colors.white, backgroundColor: Colors.grey.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                onPressed: appStateProvider.appSettings.songPlaces.isEmpty? null : () async {
                  debugPrint("Pressed");
                  appStateProvider.appSettings.firstTime = false;
                  debugPrint(appStateProvider.appSettings.firstTime.toString());
                  appStateProvider.updateAppSettings();
                  Navigator.push(context, LoadingScreen.route());
                },
                child: Icon(FluentIcons.forward, color: Colors.white, size: height * 0.03,),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
