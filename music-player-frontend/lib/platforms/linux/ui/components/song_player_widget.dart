import 'dart:typed_data';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/ui/components/animated_background.dart';
import 'package:music_player_frontend/core/ui/components/song_player_widget.dart';
import 'package:music_player_frontend/platforms/linux/providers/app_state_provider.dart';
import 'package:music_player_frontend/platforms/linux/providers/audio_provider.dart';
import 'package:music_player_frontend/utils/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class LinuxSongPlayerWidget extends SongPlayerWidget {
  const LinuxSongPlayerWidget({super.key});

  @override
  State<SongPlayerWidget> createState() => LinuxSongPlayerWidgetState();
}

class LinuxSongPlayerWidgetState extends SongPlayerWidgetState {
  late AppStateProvider appStateProvider;

  @override
  double getMinHeight(BuildContext context) {
    throw UnimplementedError();
  }

  @override
  double getMaxHeight(BuildContext context) {
    throw UnimplementedError();
  }

  @override
  double getMinWidth(BuildContext context) {
    throw UnimplementedError();
  }

  @override
  double getMaxWidth(BuildContext context) {
    throw UnimplementedError();
  }

  @override
  double getItemExtent(BuildContext context) {
    throw UnimplementedError();
  }

  @override
  Widget buildMinimizedPlayerContent(BuildContext context, double percentage) {
    throw UnimplementedError();
  }

  @override
  Widget buildMaximizedPlayerContent(BuildContext context, double percentage) {
    throw UnimplementedError();
  }

  @override
  Widget buildPlayPauseButton(BuildContext context, {bool expanded = false}) {
    throw UnimplementedError();
  }

  @override
  Widget buildNextButton(BuildContext context, {bool expanded = false}) {
    throw UnimplementedError();
  }

  @override
  Widget buildPreviousButton(BuildContext context, {bool expanded = false}) {
    throw UnimplementedError();
  }

  @override
  Widget buildShuffleButton(BuildContext context, {bool expanded = false}) {
    return ValueListenableBuilder(
      valueListenable: audioProvider.shuffleNotifier,
      builder: (context, shuffle, child) {
        return IconButton(
          onPressed: () {
            audioProvider.setShuffle(!audioProvider.shuffleNotifier.value);
          },
          icon: Icon(
            shuffle == false ? FluentIcons.shuffleOff : FluentIcons.shuffleOn,
            size: height * 0.025,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(1, 2),
                blurRadius: 7,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget buildRepeatButton(BuildContext context, {bool expanded = false}) {
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;

    appStateProvider = Provider.of<AppStateProvider>(context, listen: false);

    return Consumer<AudioProvider>(
      builder: (_, audioProvider, __) {
        debugPrint(
          "Building SongPlayerWidget, current song: ${audioProvider.currentSong.name}",
        );
        if (audioProvider.queue.isEmpty) {
          debugPrint("Queue is empty, not showing player");
          return const SizedBox.shrink();
        }
        final ValueNotifier<double> playerExpandProgress =
            ValueNotifier<double>(height * 0.1);
        return Miniplayer(
          valueNotifier: playerExpandProgress,
          minHeight: height * 0.1,
          maxHeight: height - appWindow.titleBarHeight,
          controller: appStateProvider.miniPlayerController,
          elevation: 4,
          curve: Curves.easeOut,
          tapToCollapse: false,
          duration: const Duration(milliseconds: 500),
          builder: (_, percentage) {
            final bool minimized = percentage < 0.25;

            if (minimized) {
              return _buildMinimizedPlayer(audioProvider, percentage);
            }

            if (appStateProvider.itemScrollController.hasClients) {
              int currentSongIndex = audioProvider.queue.indexOf(
                audioProvider.currentSong.path,
              );
              Future.delayed(const Duration(milliseconds: 500), () {
                try {
                  appStateProvider.itemScrollController.animateTo(
                    height * 0.1 * currentSongIndex,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  );
                } catch (e) {
                  debugPrint("Error animating to current song index: $e");
                }
              });
            }

            return _buildMaximizedPlayer(audioProvider, percentage);
          },
        );
      },
    );
  }

  Widget _buildMinimizedPlayer(AudioProvider audioProvider, double percentage) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    double minLeftMargin = 0;
    double maxLeftMargin = width * 0.75;
    double imageLeftMargin =
        lerpDouble(minLeftMargin, maxLeftMargin, percentage) ?? 0.0;
    if (imageLeftMargin < 0) {
      imageLeftMargin = 0;
    }

    double minRadius = width * 0.0075;
    double maxRadius = width * 0.01;
    double borderRadius = lerpDouble(maxRadius, minRadius, percentage) ?? 0.0;

    double normalized = (1.0 - (percentage / 0.25).clamp(0.0, 1.0));
    double progressBarOpacity = normalized;

    return AnimatedBackground(
      key: const Key("minimizedPlayer"),
      height: height * 0.15,
      width: width,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(
        top: height * 0.005,
        bottom: height * 0.005,
        left: width * 0.01,
        right: width * 0.01,
      ),
      child: Row(
        children: [
          Container(
            alignment: Alignment.center,
            margin: EdgeInsets.only(left: imageLeftMargin),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(borderRadius),
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image:
                        Image.memory(audioProvider.image ?? Uint8List(0)).image,
                  ),
                ),
              ),
            ),
          ),

          Opacity(
            opacity: progressBarOpacity,
            child: SizedBox(
              width: width * 0.3,
              height: height * 0.15,
              child: _buildPlayerButtons(audioProvider),
            ),
          ),

          const Spacer(),

          Opacity(
            opacity: progressBarOpacity,
            child: SizedBox(
              width: width * 0.3,
              height: height * 0.15,
              child: IgnorePointer(
                ignoring: true,
                child: LyricsTab(oneLine: true),
              ),
            ),
          ),

          const Spacer(),

          Opacity(
            opacity: progressBarOpacity,
            child: IconButton(
              onPressed: () async {
                appStateProvider.miniPlayerController.animateToHeight(
                  state: PanelState.MAX,
                );
              },
              icon: Icon(
                FluentIcons.maximize,
                color: Colors.white,
                size: width * 0.01,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaximizedPlayer(AudioProvider audioProvider, double percentage) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    double normalizedPercentage = ((percentage - 0.25) / 0.75).clamp(0.0, 1.0);

    double fadeStart = 0.5;
    double fadeEnd = 1.0;
    double normalized = ((percentage - fadeStart) / (fadeEnd - fadeStart))
        .clamp(0.0, 1.0);

    double progressBarHeight = lerpDouble(0.0, height * 0.05, normalized)!;
    double buttonsHeight = lerpDouble(0.0, height * 0.15, normalized)!;
    double progressBarOpacity = normalized;

    double topPadding = lerpDouble(height * 0.005, height * 0.02, percentage)!;
    double bottomPadding =
        lerpDouble(height * 0.005, height * 0.02, percentage)!;

    final showSidePanels = normalizedPercentage > 0.7;
    final sidePanelsOpacity = ((normalizedPercentage - 0.7) / 0.3).clamp(
      0.0,
      1.0,
    );

    final maxRightMargin = width * 0.45;
    final imageRightMargin =
        showSidePanels
            ? 0.0
            : lerpDouble(
              maxRightMargin,
              0.0,
              normalizedPercentage.clamp(0.0, 0.7) / 0.7,
            )!; // Only moves when panels are gone

    final detailsOpacity = ((percentage - 0.7) / 0.3).clamp(0.0, 1.0);

    if (showSidePanels) {
      if (appStateProvider.itemScrollController.hasClients) {
        debugPrint("Jumping to current song index in queue");
        int currentSongIndex = audioProvider.queue.indexOf(
          audioProvider.currentSong.path,
        );
        if (currentSongIndex > 15) {
          appStateProvider.itemScrollController.jumpTo(
            height * 0.1 * (currentSongIndex - 10),
          );
        }
        appStateProvider.itemScrollController.animateTo(
          height * 0.1 * currentSongIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }

    return AnimatedBackground(
      key: const Key("maximizedPlayer"),
      height: MediaQuery.of(context).size.height - appWindow.titleBarHeight,
      width: width,
      alignment: Alignment.center,
      padding: EdgeInsets.only(
        top: topPadding,
        bottom: bottomPadding,
        left: width * 0.01,
        right: width * 0.01,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Queue
                if (showSidePanels)
                  Opacity(
                    opacity: sidePanelsOpacity,
                    child: SizedBox(
                      width: width * 0.3,
                      height: width * 0.31,
                      child: QueueTab(),
                    ),
                  ),

                // Album Art
                Container(
                  alignment: Alignment.center,
                  constraints: BoxConstraints(maxWidth: width * 0.325),
                  margin: EdgeInsets.only(right: imageRightMargin),
                  // width: width * 0.325,
                  child: DetailsTab(opacity: detailsOpacity),
                ),

                // Lyrics
                if (showSidePanels)
                  Opacity(
                    opacity: sidePanelsOpacity,
                    child: SizedBox(
                      width: width * 0.3,
                      height: width * 0.31,
                      child: LyricsTab(),
                    ),
                  ),
              ],
            ),
          ),

          // ProgressBar
          Opacity(
            opacity: progressBarOpacity,
            child: SizedBox(
              height: progressBarHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.03),
                child:
                    percentage > 0.9
                        ? FutureBuilder(
                          future: audioProvider.getDuration(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: LinearProgressIndicator(
                                  color: Colors.white,
                                  backgroundColor: Colors.white24,
                                ),
                              );
                            }
                            return ValueListenableBuilder(
                              valueListenable: audioProvider.sliderNotifier,
                              builder: (context, value, child) {
                                return ProgressBar(
                                  progress: Duration(milliseconds: value),
                                  total:
                                      snapshot.hasData
                                          ? snapshot.data as Duration
                                          : Duration.zero,
                                  progressBarColor: appStateProvider.darkColor,
                                  baseBarColor: appStateProvider.darkColor
                                      .withValues(alpha: 0.25),
                                  thumbColor: Colors.white,
                                  barHeight: 4.0,
                                  thumbRadius: 7.0,
                                  timeLabelLocation: TimeLabelLocation.sides,
                                  timeLabelTextStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: height * 0.02,
                                    fontWeight: FontWeight.normal,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.75,
                                        ),
                                        offset: const Offset(1, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  timeLabelPadding: 5.0,
                                  onSeek: (duration) {
                                    audioProvider.seek(duration);
                                  },
                                );
                              },
                            );
                          },
                        )
                        : Center(
                          child: LinearProgressIndicator(
                            color: Colors.white,
                            backgroundColor: Colors.white24,
                          ),
                        ),
              ),
            ),
          ),

          // Player Controls - Previous, Play/Pause, Next
          Opacity(
            opacity: progressBarOpacity,
            child: SizedBox(
              width: width * 0.9,
              height: buttonsHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () async {
                      debugPrint("Liked");
                      var songProvider = Provider.of<SongProvider>(
                        context,
                        listen: false,
                      );
                      audioProvider.currentSong.liked =
                          !audioProvider.currentSong.liked;
                      songProvider.updateSong(audioProvider.currentSong);
                      likedNotifier.value = !likedNotifier.value;
                      String message =
                          audioProvider.currentSong.liked
                              ? "Added ${audioProvider.currentSong.name} to Favorites"
                              : "Removed ${audioProvider.currentSong.name} from Favorites";
                      BotToast.showText(
                        text: message,
                        duration: const Duration(seconds: 3),
                        contentColor: Colors.black,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: height * 0.02,
                        ),
                      );
                    },
                    icon: Icon(
                      audioProvider.currentSong.liked
                          ? FluentIcons.liked
                          : FluentIcons.unliked,
                      size: height * 0.025,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          offset: const Offset(1, 2),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    width: width * 0.5,
                    child: _buildPlayerButtons(audioProvider),
                  ),

                  IconButton(
                    onPressed: () async {
                      appStateProvider.miniPlayerController.animateToHeight(
                        state: PanelState.MIN,
                      );
                    },
                    icon: Icon(
                      FluentIcons.minimize,
                      color: Colors.white,
                      size: width * 0.01,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          offset: const Offset(1, 2),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerButtons(AudioProvider audioProvider) {
    var height = MediaQuery.of(context).size.height;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () async {
            await audioProvider.skipToPrevious();
          },
          icon: Icon(
            FluentIcons.previous,
            color: Colors.white,
            size: height * 0.025,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(1, 2),
                blurRadius: 7,
              ),
            ],
          ),
        ),
        ValueListenableBuilder(
          valueListenable: audioProvider.playingNotifier,
          builder: (context, value, child) {
            return IconButton(
              onPressed: () async {
                //debugPrint("pressed pause play");
                if (audioProvider.playingNotifier.value) {
                  await audioProvider.pause();
                } else {
                  await audioProvider.play();
                }
              },
              icon: Icon(
                value ? FluentIcons.pause : FluentIcons.play,
                color: Colors.white,
                size: height * 0.025,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(1, 2),
                    blurRadius: 7,
                  ),
                ],
              ),
            );
          },
        ),

        IconButton(
          onPressed: () async {
            debugPrint("next");
            return await audioProvider.skipToNext();
          },
          icon: Icon(
            FluentIcons.next,
            color: Colors.white,
            size: height * 0.025,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(1, 2),
                blurRadius: 7,
              ),
            ],
          ),
        ),
        ValueListenableBuilder(
          valueListenable: audioProvider.repeatNotifier,
          builder: (context, value, child) {
            return IconButton(
              onPressed: () {
                audioProvider.setRepeat(!audioProvider.repeatNotifier.value);
              },
              icon: Icon(
                value == false ? FluentIcons.repeatOff : FluentIcons.repeatOn,
                size: height * 0.025,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(1, 2),
                    blurRadius: 7,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
