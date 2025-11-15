import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/artist_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_component.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/platforms/android/providers/audio_provider.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/linux_search_header.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/artist_screen.dart';
import 'package:provider/provider.dart';

class Artists extends StatefulWidget {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/artists'),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const Artists();
      },
    );
  }

  const Artists({super.key});

  @override
  State<Artists> createState() => _ArtistsState();
}

class _ArtistsState extends State<Artists> {
  ValueNotifier<List<Artist>> selected = ValueNotifier<List<Artist>>([]);

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
          child: Consumer<ArtistProvider>(
            builder: (context, artistProvider, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: height * 0.065,
                    width: width,
                    padding: EdgeInsets.symmetric(horizontal: width * 0.01),
                    child: LinuxSearchHeader(
                      title: 'Artists',
                      provider: artistProvider,
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder(
                      future: artistProvider.query,
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
                              "Error loading artists",
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
                          "Artists loaded: ${snapshot.data?.length ?? 0}",
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
                                builder: (_, value, __) {
                                  return CustomGridComponent(
                                    items: snapshot.data ?? [],
                                    isSelected: (entity) {
                                      return value.contains(entity);
                                    },
                                    onTap: (entity) async {
                                      if (entity is Artist) {
                                        if (selected.value.isNotEmpty) {
                                          if (selected.value.contains(entity)) {
                                            selected.value = List<Artist>.from(
                                              selected.value,
                                            )..remove(entity);
                                          } else {
                                            selected.value = List<Artist>.from(
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
                                              ArtistScreen.route(
                                                artist: entity,
                                              ),
                                            );
                                      } else {
                                        debugPrint("Entity is not an Artist");
                                      }
                                    },
                                    onLongPress: (entity) {
                                      debugPrint("long pressed ${entity.name}");
                                      if (entity is Artist) {
                                        if (selected.value.contains(entity)) {
                                          selected.value = List<Artist>.from(
                                            selected.value,
                                          )..remove(entity);
                                        } else {
                                          selected.value = List<Artist>.from(
                                            selected.value,
                                          )..add(entity);
                                        }
                                      }
                                    },
                                    buildLeftAction: (entity) {
                                      if (selected.value.contains(entity)) {
                                        return const SizedBox.shrink();
                                      }
                                      return IconButton(
                                        icon: Icon(
                                          FluentIcons.play,
                                          color: Colors.white,
                                          size: height * 0.025,
                                        ),
                                        onPressed: () async {
                                          debugPrint(
                                            "Playing artist ${entity.name}",
                                          );
                                          if (entity is! Artist) {
                                            debugPrint(
                                              "Entity is not an Artist",
                                            );
                                            return;
                                          }
                                          Artist artist = entity;
                                          var audioProvider =
                                              Provider.of<AudioProvider>(
                                                context,
                                                listen: false,
                                              );
                                          audioProvider.setQueue(artist.songs);
                                          await audioProvider.setCurrentSong(
                                            artist.songs.first,
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
                                        return SizedBox.shrink();
                                      }
                                      return PopupMenuButton<String>(
                                        icon: Icon(
                                          FluentIcons.moreVertical,
                                          color: Colors.white,
                                          size: height * 0.03,
                                        ),
                                        onSelected: (String value) {
                                          switch (value) {
                                            case 'add':
                                              Artist artist = entity as Artist;
                                              var abstractAppStateProvider =
                                                  Provider.of<
                                                    AbstractAppStateProvider
                                                  >(context, listen: false);
                                              abstractAppStateProvider
                                                  .navigatorKey
                                                  .currentState!
                                                  .push(
                                                    AddOrExportScreen.route(
                                                      songs: artist.songs,
                                                    ),
                                                  );
                                              break;
                                            case 'playNext':
                                              Artist artist = entity as Artist;
                                              var audioProvider =
                                                  Provider.of<AudioProvider>(
                                                    context,
                                                    listen: false,
                                                  );
                                              audioProvider
                                                  .addMultipleNextToQueue(
                                                    artist.songs,
                                                  );
                                              break;
                                            case 'select':
                                              Artist artist = entity as Artist;
                                              if (selected.value.contains(
                                                entity,
                                              )) {
                                                selected
                                                    .value = List<Artist>.from(
                                                  selected.value,
                                                )..remove(artist);
                                              } else {
                                                selected
                                                    .value = List<Artist>.from(
                                                  selected.value,
                                                )..add(artist);
                                              }
                                              break;
                                          }
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
