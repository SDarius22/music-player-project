import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:musicplayer/utils/fluenticons/fluenticons.dart';
import 'package:musicplayer/entities/song.dart';
import 'package:musicplayer/components/image_widget.dart';

class TrackScreen extends StatefulWidget {
  static Route<void> route({required Song song}) {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/song', arguments: Song),
      pageBuilder: (context, animation, secondaryAnimation) {
        return TrackScreen(song: song,);
      },
    );
  }
  final Song song;
  const TrackScreen({super.key, required this.song});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    //var smallSize = height * 0.015;
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
                  widget.song.name,
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
                            tag: widget.song.path,
                            child: Container(
                              height: height * 0.5,
                              width: height * 0.5,
                              padding: EdgeInsets.only(
                                bottom: height * 0.01,
                              ),
                              //color: Colors.red,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(width * 0.025),
                                child: ImageWidget(
                                  path: widget.song.path,
                                  type: ImageWidgetType.song,
                                )
                              ),
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
                                    // dc.updatePlaying([widget.song.path], 0);
                                    // SettingsController.index = SettingsController.currentQueue.indexOf(widget.song.path);
                                    // await AppAudioHandler.play();
                                  },
                                  icon: Icon(
                                    FluentIcons.play,
                                    color: Colors.white,
                                    size: height * 0.025,
                                  ),
                                ),
                                IconButton(
                                  onPressed: (){
                                    debugPrint("Add ${widget.song.name}");
                                    // Navigator.pushNamed(context, '/add', arguments: [widget.song]);
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
                          SliverList(
                            delegate: SliverChildListDelegate(
                              [
                                Text(
                                  "Track Details",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: boldSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: height * 0.01,),
                                Text(
                                  "Song Name:",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: normalSize,
                                  ),
                                ),
                                Text(
                                  widget.song.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize,
                                  ),
                                ),
                                SizedBox(height: height * 0.01,),
                                Text(
                                  "Artist:",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: normalSize,
                                  ),
                                ),
                                Text(
                                  widget.song.trackArtist,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize,
                                  ),
                                ),
                                SizedBox(height: height * 0.01,),
                                Text(
                                  "Album:",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: normalSize,
                                  ),
                                ),
                                Text(
                                  widget.song.album,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize,
                                  ),
                                ),
                                SizedBox(height: height * 0.01,),
                                Text(
                                  "Album Artist:",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: normalSize,
                                  ),
                                ),
                                Text(
                                  widget.song.albumArtist,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize,
                                  ),
                                ),
                                SizedBox(height: height * 0.01,),
                                Text(
                                  "Duration:",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: normalSize,
                                  ),
                                ),
                                Text(
                                  Duration(seconds: widget.song.duration).pretty(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize,
                                  ),
                                ),
                                SizedBox(height: height * 0.01,),
                                Text(
                                  "Genre:",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: normalSize,
                                  ),
                                ),
                                Text(
                                  widget.song.genre,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize,
                                  ),
                                ),
                                SizedBox(height: height * 0.01,),
                                Text(
                                  "Year:",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: normalSize,
                                  ),
                                ),
                                Text(
                                  widget.song.year > 0 ? widget.song.year.toString() : "Unknown year",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize,
                                  ),
                                ),
                                SizedBox(height: height * 0.01,),
                                Text(
                                  "Extra Info:",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: normalSize,
                                  ),
                                ),
                                Text(
                                  "Track: ${widget.song.trackNumber} / Disc: ${widget.song.discNumber}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize,
                                  ),
                                ),
                                Text(
                                  "Play Count: ${widget.song.playCount}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize,
                                  ),
                                ),
                                Text(
                                  "Last Played: ${widget.song.lastPlayed != null ? widget.song.lastPlayed!.toLocal().toString() : "Never"}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize,
                                  ),
                                ),
                                Text(
                                  "Lyrics: ${widget.song.lyricsPath.isNotEmpty ? widget.song.lyricsPath : "No lyrics available"}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize,
                                  ),
                                ),
                                Text(
                                  "Path: ${widget.song.path}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize,
                                  )
                                ),

                              ]
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