import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:musicplayer/components/custom_tiling/grid_component.dart';
import 'package:musicplayer/providers/app_state_provider.dart';
import 'package:musicplayer/providers/audio_provider.dart';
import 'package:musicplayer/providers/playlist_provider.dart';
import 'package:musicplayer/services/file_service.dart';
import 'package:musicplayer/utils/fluenticons/fluenticons.dart';
import 'package:musicplayer/entities/playlist.dart';
import 'package:musicplayer/entities/song.dart';
import 'package:provider/provider.dart';

class AddOrExportScreen extends StatefulWidget {
  final List<Song> songs;
  final bool export;

  static Route route({List<Song> songs = const [], bool export = false}) {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/add', arguments: [List<Song>, bool]),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AddOrExportScreen(songs: songs, export: export);
      },
    );
  }


  const AddOrExportScreen({super.key, this.songs = const [], this.export = false});

  @override
  State<AddOrExportScreen> createState() => _AddOrExportScreenState();
}

class _AddOrExportScreenState extends State<AddOrExportScreen> {
  ValueNotifier<List<Playlist>> selected = ValueNotifier<List<Playlist>>([]);

  @override
  Widget build(BuildContext context) {
    //debugPrint(widget.songs.length);
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
            bottom: height * 0.02
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                SizedBox(
                  width: width * 0.01,
                ),
                Text(
                  "Choose one or more playlists to ${
                    widget.export ? 'export' : 'add to'
                  }",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: normalSize,
                      fontWeight: FontWeight.bold
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                    onPressed: (){
                      if (selected.value.isEmpty) {
                        BotToast.showText(
                          text: "Please select at least one playlist",
                        );
                        return;
                      }
                      debugPrint("Add to new playlist");
                      if (widget.export) {
                        var appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
                        for (int i = 0; i < selected.value.length; i++) {
                          Playlist playlist = selected.value[i];
                          var fileName = "${appStateProvider.appSettings.mainSongPlace}/${playlist.name}.m3u";
                          FileService.exportPlaylist(
                            fileName,
                            playlist.pathsInOrder,
                          );
                        }
                      }
                      for(int i = 0; i < selected.value.length; i++){
                        Playlist playlist = selected.value[i];
                        if (playlist.indestructible && playlist.name == 'Current Queue') {
                          var audioProvider = Provider.of<AudioProvider>(context, listen: false);
                          audioProvider.addMultipleToQueue(widget.songs.map((song) => song.path).toList());
                        }
                        else {
                          var playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
                          playlistProvider.addSongsToPlaylist(playlist, widget.songs);
                        }
                      }
                      Navigator.pop(context);
                    },
                    child: Text(
                      "Done",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: normalSize
                      ),
                    )
                ),

              ],
            ),
            Expanded(
              child: Consumer<PlaylistProvider>(
                builder: (_, playlistProvider, __){
                  return FutureBuilder(
                      future: Future(() => widget.export ? playlistProvider.getPlaylists() : playlistProvider.getNormalPlaylists()),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          debugPrint(snapshot.error.toString());
                          debugPrintStack();
                          return Center(
                            child: Text(
                              "Error loading playlists",
                              style: TextStyle(color: Colors.white, fontSize: smallSize),
                            ),
                          );
                        }
                        List<Playlist> items = snapshot.data ?? [];
                        Playlist queue = Playlist();
                        queue.name = "Current Queue";
                        var audioProvider = Provider.of<AudioProvider>(context, listen: false);
                        queue.pathsInOrder = audioProvider.queue;
                        queue.indestructible = true;
                        items.insert(0, queue);
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
                                    return GridComponent(
                                      items: items,
                                      isSelected: (entity) {
                                        return selected.value.contains(entity as Playlist);
                                      },
                                      onTap: (entity) {
                                        debugPrint("Tapped on ${entity.name}");
                                        if (selected.value.contains(entity as Playlist)) {
                                          selected.value = List<Playlist>.from(selected.value)..remove(entity);
                                        } else {
                                          selected.value = List<Playlist>.from(selected.value)..add(entity);
                                        }
                                      },
                                      onLongPress: (entity) {
                                        debugPrint("Long pressed on ${entity.name}");
                                      },
                                    );
                                  },
                                ),
                              ),
                            ]
                        );
                      }
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}