import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/entity_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class TrackScreen extends EntityScreen {
  static Route<void> route({required Song song}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return TrackScreen(entity: song as BaseEntity);
      },
    );
  }

  const TrackScreen({super.key, required super.entity});

  @override
  EdgeInsetsGeometry buildPadding(double width, double height) {
    return EdgeInsets.only(bottom: height * 0.01);
  }

  @override
  Widget buildBody(BuildContext context, double width, double height) {
    var song = entity as Song;
    var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
              song.name,
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
                  padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: song.path,
                        child: Container(
                          height: height * 0.5,
                          width: height * 0.5,
                          padding: EdgeInsets.only(bottom: height * 0.01),
                          //color: Colors.red,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              MediaQuery.of(context).size.height * 0.015,
                            ),
                            child: ImageWidget(entity: song),
                          ),
                        ),
                      ),
                      SizedBox(height: height * 0.01),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () async {
                              debugPrint("Play ${song.name}");
                              var audioProvider = Provider.of<AudioProvider>(
                                context,
                                listen: false,
                              );
                              audioProvider.setQueue([song]);
                              await audioProvider.setCurrentSong(song);
                              audioProvider.play();
                            },
                            icon: Icon(
                              FluentIcons.play,
                              color: Colors.white,
                              size: height * 0.025,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              debugPrint("Add ${song.name}");
                              // Navigator.pushNamed(context, '/add', arguments: [song]);
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
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(width * 0.01),
                  margin: EdgeInsets.only(top: height * 0.02),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      MediaQuery.of(context).size.height * 0.015,
                    ),
                    color: const Color(0xFF242424),
                  ),
                  child: CustomScrollView(
                    slivers: [
                      SliverList(
                        delegate: SliverChildListDelegate([
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
                            song.name,
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
                            song.artist.toString(),
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
                            song.album.toString(),
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
                            Duration(seconds: song.durationInSeconds).pretty(),
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
                            song.year > 0
                                ? song.year.toString()
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
                            "Track: ${song.trackNumber} / Disc: ${song.discNumber}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: normalSize,
                            ),
                          ),
                          Text(
                            "Play Count: ${song.playCount}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: normalSize,
                            ),
                          ),
                          Text(
                            "Last Played: ${song.lastPlayed != null ? song.lastPlayed!.toLocal().toString() : "Never"}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: normalSize,
                            ),
                          ),
                          Text(
                            "Path: ${song.path}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: normalSize,
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: width * 0.025),
            ],
          ),
        ),
      ],
    );
  }
}
