import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:musicplayer/components/custom_tiling/list_component.dart';
import 'package:musicplayer/entities/song.dart';
import 'package:musicplayer/providers/app_state_provider.dart';
import 'package:musicplayer/providers/audio_provider.dart';
import 'package:musicplayer/screens/add_or_export_screen.dart';
import 'package:musicplayer/utils/fluenticons/fluenticons.dart';
import 'package:musicplayer/entities/album.dart';
import 'package:musicplayer/components/image_widget.dart';
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
    var smallSize = height * 0.015;
    return Scaffold(
      body: Container(
        width: width,
        height: height,
        padding: EdgeInsets.only(
            top: height * 0.02,
            left: width * 0.01,
            right: width * 0.01,
            bottom: height * 0.125
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: (){
                    debugPrint("Back");
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    FluentIcons.back,
                    size: height * 0.02,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.album.name,
                  style: TextStyle(
                    fontSize: boldSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
              ],
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.05,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children:[
                          Hero(
                            tag: widget.album.name,
                            child: Container(
                              height: height * 0.5,
                              width: height * 0.5,
                              padding: EdgeInsets.only(
                                bottom: height * 0.01,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(width * 0.025),
                                child: ImageWidget(
                                  path: widget.album.songs.isNotEmpty
                                      ? widget.album.songs.first.path
                                      : '',
                                  type: ImageWidgetType.song,
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
                          SizedBox(
                            height: height * 0.005,
                          ),
                          Text(
                            widget.album.songs.first.albumArtist,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: normalSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            height: height * 0.005,
                          ),
                          Text(
                            Duration(seconds: widget.album.duration,).pretty(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: smallSize,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          SizedBox(
                            height: height * 0.01,
                          ),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    debugPrint("Play ${widget.album.name}");
                                    List<String> songPaths = widget.album.songs.map((e) => e.path).toList();
                                    var audioProvider = Provider.of<AudioProvider>(context, listen: false);
                                    audioProvider.setQueue(songPaths);
                                    await audioProvider.setCurrentIndex(widget.album.songs.first.path);
                                  },
                                  icon: Icon(
                                    FluentIcons.play,
                                    color: Colors.white,
                                    size: height * 0.025,
                                  ),
                                ),
                                IconButton(
                                  onPressed: (){
                                    debugPrint("Add ${widget.album.name}");
                                    var appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
                                    appStateProvider.navigatorKey.currentState?.push(AddOrExportScreen.route(songs: widget.album.songs));
                                  },
                                  icon: Icon(
                                    FluentIcons.add,
                                    color: Colors.white,
                                    size: height * 0.025,
                                  ),
                                ),
                              ]
                          ),
                        ]
                      ),
                    )
                  ),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(width * 0.01),
                      margin: EdgeInsets.only(
                        top: height * 0.02,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(width * 0.02),
                        color: const Color(0xFF242424),
                      ),
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.only(
                              bottom: height * 0.02,
                            ),
                            sliver: ListComponent(
                              items: widget.album.songs,
                              itemExtent: height * 0.125,
                              isSelected: (entity) {
                                return false;
                              },
                              onTap: (entity) async {
                                debugPrint("Tapped on ${entity.name}");
                                List<String> songPaths = widget.album.songs.map((e) => e.path).toList();
                                var audioProvider = Provider.of<AudioProvider>(context, listen: false);
                                audioProvider.setQueue(songPaths);
                                await audioProvider.setCurrentIndex((entity as Song).path);
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
                  SizedBox(
                    width: width * 0.025,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}