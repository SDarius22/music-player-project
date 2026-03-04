import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';

class TrackScreen extends StatefulWidget {
  static Route<void> route({required Song song}) {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/song', arguments: Song),
      pageBuilder: (context, animation, secondaryAnimation) {
        return TrackScreen(song: song);
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: width,
        height: height,
        padding: EdgeInsets.only(
          top: height * 0.02,
          left: width * 0.01,
          right: width * 0.01,
          bottom: height * 0.125,
        ),
        child: Column(
          children: [
            Row(
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
            SizedBox(height: height * 0.02),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.05),
              child: Column(
                children: [
                  Hero(
                    tag: widget.song.path,
                    child: Container(
                      height: width * 0.7,
                      width: width * 0.7,
                      padding: EdgeInsets.only(bottom: height * 0.01),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          MediaQuery.of(context).size.height * 0.015,
                        ),
                        child: ImageWidget(entity: widget.song),
                      ),
                    ),
                  ),
                  SizedBox(height: height * 0.02),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () async {
                          // Play functionality
                        },
                        icon: Icon(
                          FluentIcons.play,
                          color: Colors.white,
                          size: height * 0.025,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          debugPrint("Add ${widget.song.name}");
                          // Add functionality
                        },
                        icon: Icon(
                          FluentIcons.add,
                          color: Colors.white,
                          size: height * 0.025,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: height * 0.02),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(width * 0.05),
                margin: EdgeInsets.symmetric(horizontal: width * 0.05),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    MediaQuery.of(context).size.height * 0.015,
                  ),
                  color: const Color(0xFF242424),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Track Details",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: boldSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: height * 0.01),
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
                      SizedBox(height: height * 0.01),
                      Text(
                        "Artist:",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: normalSize,
                        ),
                      ),
                      Text(
                        widget.song.artist.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: normalSize,
                        ),
                      ),
                      SizedBox(height: height * 0.01),
                      Text(
                        "Album:",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: normalSize,
                        ),
                      ),
                      Text(
                        widget.song.album.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: normalSize,
                        ),
                      ),
                      SizedBox(height: height * 0.01),
                      Text(
                        "Duration:",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: normalSize,
                        ),
                      ),
                      Text(
                        Duration(
                          seconds: widget.song.durationInSeconds,
                        ).pretty(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: normalSize,
                        ),
                      ),
                      SizedBox(height: height * 0.01),
                      SizedBox(height: height * 0.01),
                      Text(
                        "Year:",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: normalSize,
                        ),
                      ),
                      Text(
                        widget.song.year > 0
                            ? widget.song.year.toString()
                            : "Unknown year",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: normalSize,
                        ),
                      ),
                      SizedBox(height: height * 0.01),
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
                        "Path: ${widget.song.path}",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: normalSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
