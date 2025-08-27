import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/drawer_widget.dart';
import 'package:music_player_frontend/core/ui/components/widgets/song_player_widget.dart';
import 'package:music_player_frontend/core/ui/components/widgets/volume_widget.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/widgets/linux_top_bar_widget.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/tracks.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/home'),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const HomeScreen();
      },
    );
  }

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(actions: [VolumeWidget()]),
      body: Stack(
        children: [
          Row(
            children: [
              const DrawerWidget(),
              Consumer<AbstractAppStateProvider>(
                builder: (context, abstractAppStateProvider, child) {
                  return Theme(
                    data: abstractAppStateProvider.themeData,
                    child: Expanded(
                      child: HeroControllerScope(
                        controller: MaterialApp.createMaterialHeroController(),
                        child: Navigator(
                          key: abstractAppStateProvider.navigatorKey,
                          // observers: [SecondNavigatorObserver()],
                          onGenerateRoute: (settings) {
                            return Tracks.route();
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            alignment: Alignment.bottomCenter,
            child: const SongPlayerWidget(),
          ),

          // ValueListenableBuilder(
          //   valueListenable: _dragging,
          //   builder: (context, value, child) {
          //     return DropTarget(
          //         onDragDone: (detail) async {
          //           List<String> songs = [];
          //           for (final file in detail.files) {
          //             if (file.path.endsWith(".mp3") ||
          //                 file.path.endsWith(".wav") ||
          //                 file.path.endsWith(".flac") ||
          //                 file.path.endsWith(".m4a")) {
          //               songs.add(file.path);
          //             }
          //           }
          //           if (songs.isNotEmpty) {
          //             // widget.controller.finishedRetrievingNotifier.value = false;
          //             for (var song in songs) {
          //               await DataController.getSong(song);
          //             }
          //             final dc = DataController();
          //             dc.updatePlaying(songs, 0);
          //             SettingsController.index =
          //                 SettingsController.currentQueue.indexOf(songs[0]);
          //             await AppAudioHandler.play();
          //             // DataController.indexChange(songs[0]);
          //             // await widget.controller.playSong();
          //             //widget.controller.showNotification("Playing ${songs.length} new song${songs.length == 1 ? '' : 's'}. Do you want to add ${songs.length == 1 ? 'it' : 'them'} to your library?", 7500);
          //             // final am = AppManager();
          //             // am.showNotification(
          //             //     "Playing ${songs.length} new song${songs.length ==
          //             //         1
          //             //         ? ''
          //             //         : 's'} and adding them to your library",
          //             //     7500);
          //             //widget.controller.finishedRetrievingNotifier.value = true;
          //           }
          //         },
          //         onDragEntered: (detail) {
          //           _dragging.value = true;
          //         },
          //         onDragExited: (detail) {
          //           _dragging.value = false;
          //         },
          //         child: IgnorePointer(
          //           child: Container(
          //             width: width,
          //             height: MediaQuery
          //                 .of(context)
          //                 .size
          //                 .height,
          //             color: _dragging.value
          //                 ? Colors.black.withOpacity(0.3)
          //                 : Colors.transparent,
          //             child: _dragging.value ?
          //             Center(
          //               child: Column(
          //                 mainAxisAlignment: MainAxisAlignment.center,
          //                 children: [
          //                   Icon(
          //                     FluentIcons.drag,
          //                     size: MediaQuery
          //                         .of(context)
          //                         .size
          //                         .height * 0.1,
          //                     color: Colors.white,
          //                   ),
          //                   Text(
          //                     "Drop files here",
          //                     style: TextStyle(
          //                       color: Colors.white,
          //                       fontSize: normalSize,
          //                     ),
          //                   ),
          //                 ],
          //               ),
          //             ) :
          //             Container(),
          //           ),
          //         )
          //     );
          //   },
          // ),
        ],
      ),
    );
  }
}
