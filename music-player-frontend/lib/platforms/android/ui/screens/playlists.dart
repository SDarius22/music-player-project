import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_component.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_tile.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/linux_search_header.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/create_or_import_screen.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/playlist_screen.dart';
import 'package:provider/provider.dart';

class Playlists extends StatefulWidget {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/playlists'),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const Playlists();
      },
    );
  }

  const Playlists({super.key});

  @override
  State<Playlists> createState() => _PlaylistsState();
}

class _PlaylistsState extends State<Playlists> {
  ValueNotifier<List<Playlist>> selected = ValueNotifier<List<Playlist>>([]);
  Uint8List _createPlaylistImageBytes = Constants.logoBytes;

  @override
  void initState() {
    super.initState();
    _loadCreatePlaylistImage();
  }

  Future<void> _loadCreatePlaylistImage() async {
    final ByteData data = await rootBundle.load('assets/create_playlist.png');
    setState(() {
      _createPlaylistImageBytes = data.buffer.asUint8List();
    });
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: GlassContainer(
          height: height,
          width: width,
          color: Colors.black.withValues(alpha: 0.4),
          borderColor: Colors.transparent,
          blur: 45.0,
          borderWidth: 0.0,
          elevation: 3.0,
          shadowColor: Colors.black.withOpacity(0.20),
          padding: EdgeInsets.only(bottom: height * 0.01),
          margin: EdgeInsets.all(height * 0.01),
          borderRadius: BorderRadius.circular(height * 0.015),
          child: Consumer<PlaylistProvider>(
            builder: (context, playlistProvider, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: height * 0.065,
                    width: width,
                    padding: EdgeInsets.symmetric(horizontal: width * 0.01),
                    child: LinuxSearchHeader(
                      title: 'Playlists',
                      provider: playlistProvider,
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder(
                      future: playlistProvider.query,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          debugPrint(snapshot.error.toString());
                          debugPrintStack();
                          return Center(
                            child: Text(
                              "Error loading playlists",
                              style: MusicPlayerTheme.getTheme(
                                context,
                                context.read<Scaler>(),
                              ).textTheme.bodyMedium?.copyWith(
                                color: Colors.red,
                              ),
                            ),
                          );
                        }
                        debugPrint(
                          "Playlists loaded: ${snapshot.data?.length ?? 0}",
                        );
                        return CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.only(
                                left: width * 0.01,
                                right: width * 0.01,
                              ),
                              sliver: ValueListenableBuilder(
                                valueListenable: selected,
                                builder: (context, value, child) {
                                  return CustomGridComponent(
                                    items: snapshot.data ?? [],
                                    isSelected: (entity) {
                                      return selected.value.contains(entity);
                                    },
                                    onTap: (entity) async {
                                      if (entity is Playlist) {
                                        if (selected.value.isNotEmpty) {
                                          if (selected.value.contains(entity)) {
                                            selected
                                                .value = List<Playlist>.from(
                                              selected.value,
                                            )..remove(entity);
                                          } else {
                                            selected
                                                .value = List<Playlist>.from(
                                              selected.value,
                                            )..add(entity);
                                          }
                                          return;
                                        }
                                        var abstractAppStateProvider =
                                            Provider.of<
                                              AbstractAppStateProvider
                                            >(context, listen: false);
                                        abstractAppStateProvider
                                            .navigatorKey
                                            .currentState!
                                            .push(
                                              PlaylistScreen.route(
                                                playlist: entity,
                                              ),
                                            );
                                      } else {
                                        debugPrint("Entity is not a Playlist");
                                      }
                                    },
                                    onLongPress: (entity) {
                                      debugPrint("long pressed ${entity.name}");
                                      if (entity is Playlist) {
                                        if (selected.value.isNotEmpty) {
                                          if (selected.value.contains(entity)) {
                                            selected
                                                .value = List<Playlist>.from(
                                              selected.value,
                                            )..remove(entity);
                                          } else {
                                            selected
                                                .value = List<Playlist>.from(
                                              selected.value,
                                            )..add(entity);
                                          }
                                          return;
                                        }
                                      }
                                    },
                                    buildLeftAction: (entity) {
                                      return IconButton(
                                        icon: Icon(
                                          FluentIcons.play,
                                          color: Colors.white,
                                          size: height * 0.025,
                                        ),
                                        onPressed: () async {
                                          debugPrint(
                                            "Playing album ${entity.name}",
                                          );
                                          if (entity is! Playlist) {
                                            debugPrint(
                                              "Entity is not a Playlist",
                                            );
                                            return;
                                          }
                                          Playlist playlist = entity;
                                          final songs =
                                              playlist.playlistSongs
                                                  .sorted(
                                                    (a, b) => a.position
                                                        .compareTo(b.position),
                                                  )
                                                  .map((e) => e.song.target!)
                                                  .toList();
                                          var audioProvider = Provider.of<
                                            AbstractAudioProvider
                                          >(context, listen: false);
                                          audioProvider.setQueue(songs);
                                          await audioProvider.setCurrentSong(
                                            songs.first,
                                          );
                                        },
                                      );
                                    },
                                    buildMainAction: (entity) {
                                      if (selected.value.contains(entity)) {
                                        return Icon(
                                          FluentIcons.checkCircleOn,
                                          color: Colors.white,
                                        );
                                      }
                                      if (selected.value.isNotEmpty) {
                                        return Icon(
                                          FluentIcons.checkCircleOff,
                                          color: Colors.white,
                                        );
                                      }
                                      return Icon(
                                        FluentIcons.open,
                                        color: Colors.white,
                                        size: height * 0.03,
                                      );
                                    },
                                    buildRightAction: (entity) {
                                      if (selected.value.contains(entity)) {
                                        return const SizedBox.shrink();
                                      }
                                      return PopupMenuButton<String>(
                                        icon: Icon(
                                          FluentIcons.moreVertical,
                                          color: Colors.white,
                                          size: height * 0.03,
                                        ),
                                        onSelected: (String value) {
                                          // switch (value) {
                                          //   case 'add':
                                          //     Playlist playlist =
                                          //         entity as Playlist;
                                          //     final orderMap = {
                                          //       for (
                                          //         int i = 0;
                                          //         i <
                                          //             playlist
                                          //                 .pathsInOrder
                                          //                 .length;
                                          //         i++
                                          //       )
                                          //         playlist.pathsInOrder[i]: i,
                                          //     };
                                          //     playlist.songs.sort((a, b) {
                                          //       return (orderMap[a.path] ??
                                          //               playlist
                                          //                   .pathsInOrder
                                          //                   .length)
                                          //           .compareTo(
                                          //             orderMap[b.path] ??
                                          //                 playlist
                                          //                     .pathsInOrder
                                          //                     .length,
                                          //           );
                                          //     });
                                          //     var abstractAppStateProvider =
                                          //         Provider.of<
                                          //           AbstractAppStateProvider
                                          //         >(context, listen: false);
                                          //     abstractAppStateProvider
                                          //         .navigatorKey
                                          //         .currentState!
                                          //         .push(
                                          //           AddOrExportScreen.route(
                                          //             songs: playlist.songs,
                                          //           ),
                                          //         );
                                          //     break;
                                          //   case 'playNext':
                                          //     Playlist playlist =
                                          //         entity as Playlist;
                                          //     var audioProvider =
                                          //         Provider.of<AudioProvider>(
                                          //           context,
                                          //           listen: false,
                                          //         );
                                          //     audioProvider
                                          //         .addMultipleNextToQueue(
                                          //           playlist.pathsInOrder,
                                          //         );
                                          //     break;
                                          //   case 'select':
                                          //     Playlist playlist =
                                          //         entity as Playlist;
                                          //     if (selected.value.contains(
                                          //       playlist,
                                          //     )) {
                                          //       selected
                                          //           .value = List<Playlist>.from(
                                          //         selected.value,
                                          //       )..remove(playlist);
                                          //     } else {
                                          //       selected
                                          //           .value = List<Playlist>.from(
                                          //         selected.value,
                                          //       )..add(playlist);
                                          //     }
                                          //     break;
                                          // }
                                        },
                                        itemBuilder: (context) {
                                          return [
                                            const PopupMenuItem<String>(
                                              value: 'add',
                                              child: Text("Add to Playlist"),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'playNext',
                                              child: Text("Play Next"),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'select',
                                              child: Text("Select"),
                                            ),
                                          ];
                                        },
                                      );
                                    },
                                    buildExtraTile: () {
                                      Playlist emptyPlaylist = Playlist();
                                      emptyPlaylist.name =
                                          "Create New Playlist";
                                      emptyPlaylist.indestructible = true;
                                      emptyPlaylist.imageBytes =
                                          _createPlaylistImageBytes;
                                      return CustomGridTile(
                                        onTap: () {
                                          debugPrint(
                                            "Create new playlist tapped",
                                          );
                                          var appState = Provider.of<
                                            AbstractAppStateProvider
                                          >(context, listen: false);
                                          appState.navigatorKey.currentState
                                              ?.push(
                                                CreateOrImportScreen.route(),
                                              );
                                        },
                                        onLongPress: () {
                                          debugPrint(
                                            "Create new playlist long pressed",
                                          );
                                        },
                                        entity: emptyPlaylist,
                                        isSelected: false,
                                        mainAction: Icon(
                                          FluentIcons.add,
                                          color: Colors.white,
                                          size: height * 0.03,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
