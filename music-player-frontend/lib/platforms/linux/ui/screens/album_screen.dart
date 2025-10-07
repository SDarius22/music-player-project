import 'dart:convert';

import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/platforms/linux/providers/audio_provider.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/tiling/list_component.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/add_or_export_screen.dart';
import 'package:provider/provider.dart';

class AlbumScreen extends StatefulWidget {
  static Route<void> route({required Album album}) {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/album', arguments: Album),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlbumScreen(album: album);
      },
    );
  }

  final Album album;

  const AlbumScreen({super.key, required this.album});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  @override
  void initState() {
    super.initState();
    widget.album.songs.sort((a, b) => a.trackNumber.compareTo(b.trackNumber));
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    // var smallSize = height * 0.015;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassContainer(
        width: width,
        height: height,
        color: Colors.black.withValues(alpha: 0.4),
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.60),
            Colors.indigoAccent.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          MediaQuery.of(context).size.height * 0.015,
        ),
        blur: 45.0,
        borderWidth: 1.5,
        elevation: 3.0,
        shadowColor: Colors.black.withOpacity(0.20),
        padding: EdgeInsets.only(bottom: height * 0.01),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: height * 0.065,
              width: width,
              padding: EdgeInsets.symmetric(horizontal: width * 0.01),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                  IconButton(
                    tooltip: "Add",
                    padding: EdgeInsets.all(height * 0.005),
                    onPressed: () {
                      debugPrint("Add ${widget.album.name}");
                      var abstractAppStateProvider =
                          Provider.of<AbstractAppStateProvider>(
                            context,
                            listen: false,
                          );
                      abstractAppStateProvider.navigatorKey.currentState?.push(
                        AddOrExportScreen.route(songs: widget.album.songs),
                      );
                    },
                    icon: Icon(
                      FluentIcons.add,
                      color: Colors.white,
                      size: height * 0.025,
                    ),
                  ),
                  IconButton(
                    tooltip: "Play",
                    padding: EdgeInsets.all(height * 0.005),
                    onPressed: () async {
                      debugPrint("Play ${widget.album.name}");
                      var audioProvider = Provider.of<AbstractAudioProvider>(
                        context,
                        listen: false,
                      );
                      audioProvider.setQueue(widget.album.songs);
                      await audioProvider.setCurrentSong(
                        widget.album.songs.first,
                      );
                      audioProvider.play();
                    },
                    icon: Icon(
                      FluentIcons.play,
                      color: Colors.white,
                      size: height * 0.025,
                    ),
                  ),
                  IconButton(
                    tooltip: "Shuffle",
                    onPressed: () async {},
                    padding: EdgeInsets.all(height * 0.005),
                    icon: Icon(
                      FluentIcons.shuffleOn,
                      color: Colors.white,
                      size: height * 0.025,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Hero(
                            tag: widget.album.name,
                            child: Container(
                              height: height * 0.5,
                              width: height * 0.5,
                              padding: EdgeInsets.only(bottom: height * 0.01),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  MediaQuery.of(context).size.height * 0.015,
                                ),
                                child: ImageWidget(
                                  path: base64Encode(widget.album.coverArt),
                                  type: ImageWidgetType.bytes,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            widget.album.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: boldSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: height * 0.005),
                          Text(
                            widget.album.songs.first.artist.target?.name ??
                                'Unknown Artist',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: normalSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: height * 0.005),
                          Text(
                            "${widget.album.songs.length} Songs | ${Duration(seconds: widget.album.duration).pretty()}",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: normalSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: GlassContainer(
                      margin: EdgeInsets.only(
                        top: height * 0.025,
                        bottom: height * 0.025,
                        right: width * 0.05,
                      ),
                      padding: EdgeInsets.only(
                        right: width * 0.01,
                        top: height * 0.01,
                        bottom: height * 0.01,
                      ),
                      color: Colors.black.withValues(alpha: 0.4),
                      borderGradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.60),
                          Colors.indigoAccent.withOpacity(0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        MediaQuery.of(context).size.height * 0.015,
                      ),
                      blur: 45.0,
                      borderWidth: 1.5,
                      elevation: 3.0,
                      shadowColor: Colors.black.withOpacity(0.20),
                      isFrostedGlass: true,
                      frostedOpacity: 0.15,
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              vertical: height * 0.01,
                            ),
                            sliver: ListComponent(
                              items: widget.album.songs,
                              itemExtent: height * 0.1,
                              isSelected: (entity) {
                                return false;
                              },
                              onTap: (entity) async {
                                debugPrint("Tapped on ${entity.name}");
                                var audioProvider = Provider.of<AudioProvider>(
                                  context,
                                  listen: false,
                                );
                                audioProvider.setQueue(widget.album.songs);
                                await audioProvider.setCurrentSong(
                                  (entity as Song),
                                );
                              },
                              onLongPress: (entity) {
                                debugPrint("Long pressed on ${entity.name}");
                                // Show context menu or options
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
