import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/widgets/song_player_widget.dart';
import 'package:music_player_frontend/local_libs/audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';
import 'package:music_player_frontend/platforms/android/ui/components/tabs/details_tab.dart';
import 'package:music_player_frontend/platforms/android/ui/components/tabs/lyrics_tab.dart';
import 'package:music_player_frontend/platforms/android/ui/components/tabs/queue_tab.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_volume_widget.dart';
import 'package:provider/provider.dart';

class AndroidSongPlayerWidget extends SongPlayerWidget {
  const AndroidSongPlayerWidget({super.key});

  @override
  State<SongPlayerWidget> createState() => AndroidSongPlayerWidgetState();
}

class AndroidSongPlayerWidgetState extends SongPlayerWidgetState {
  late AbstractAppStateProvider appStateProvider;
  late AudioProvider audioProvider;
  final MiniPlayerController _miniPlayerController = MiniPlayerController();
  final ValueNotifier<bool> _listView = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    appStateProvider = context.read<AbstractAppStateProvider>();
    audioProvider = context.read<AudioProvider>();
  }

  @override
  double getMinHeight(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.075 +
        MediaQuery.of(context).padding.bottom;
  }

  @override
  double getMaxHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  @override
  double getMinWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  @override
  double getMaxWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  @override
  double getItemExtent(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.1;
  }

  @override
  BorderRadius getBorderRadius(BuildContext context) {
    return BorderRadius.only(
      topLeft: Radius.circular(MediaQuery.of(context).size.height * 0.015),
      topRight: Radius.circular(MediaQuery.of(context).size.height * 0.015),
    );
  }

  @override
  bool isMinimized(double percentage) {
    return percentage < 0.45;
  }

  @override
  Widget buildMinimizedPlayerContent(BuildContext context, double percentage) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    double minLeftMargin = 0.0;
    double maxLeftMargin = width * 0.05;
    double imageLeftMargin =
        lerpDouble(minLeftMargin, maxLeftMargin, percentage / 0.45) ?? 0.0;
    if (imageLeftMargin < 0) {
      imageLeftMargin = 0;
    }

    double minTopMargin = 0;
    double maxTopMargin = MediaQuery.of(context).size.width * 0.05;
    double imageTopMargin =
        lerpDouble(minTopMargin, maxTopMargin, percentage / 0.45) ?? 0.0;
    if (imageTopMargin < 0) {
      imageTopMargin = 0;
    }

    double minRadius = 0.0;
    double maxRadius = height * 0.015;
    double borderRadius = lerpDouble(maxRadius, minRadius, percentage) ?? 0.0;

    double normalized = (1.0 - (percentage / 0.45).clamp(0.0, 1.0));
    double progressBarOpacity = normalized;

    return GlassContainer(
      color: Colors.black.withValues(alpha: 0.3),
      borderColor: Colors.transparent,
      borderWidth: 0.0,
      blur: 45.0,
      elevation: 3.0,
      borderRadius: getBorderRadius(context),
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Container(
            alignment: Alignment.center,
            margin: EdgeInsets.only(
              left: imageLeftMargin,
              top: imageTopMargin,
              bottom: imageTopMargin,
            ),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(borderRadius),
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: cachedCoverArt,
                    isAntiAlias: true,
                  ),
                ),
              ),
            ),
          ),

          Opacity(
            opacity: progressBarOpacity,
            child: Container(
              height: height * 0.15,
              width: width * 0.3,
              margin: EdgeInsets.only(left: width * 0.01),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audioProvider.currentSong.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MusicPlayerTheme.getTheme(
                      context,
                      context.read<Scaler>(),
                    ).textTheme.headlineLarge?.copyWith(
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.75),
                          offset: const Offset(1, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    audioProvider.currentSong.artist.target?.name ??
                        'Unknown Artist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MusicPlayerTheme.getTheme(
                      context,
                      context.read<Scaler>(),
                    ).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.75),
                          offset: const Offset(1, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          Opacity(
            opacity: progressBarOpacity,
            child: SizedBox(
              width: width * 0.35,
              height: height * 0.15,
              child: _buildPlayerButtons(audioProvider),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildMaximizedPlayerContent(BuildContext context, double percentage) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    double normalizedPercentage = ((percentage - 0.45) / 0.55).clamp(0.0, 1.0);

    double fadeStart = 0.5;
    double fadeEnd = 1.0;
    double normalized = ((percentage - fadeStart) / (fadeEnd - fadeStart))
        .clamp(0.0, 1.0);

    double progressBarOpacity = normalized;

    double topButtonsHeight = lerpDouble(0.0, height * 0.05, normalized)!;

    final sidePanelsOpacity = ((normalizedPercentage - 0.8) / 0.2).clamp(
      0.0,
      1.0,
    );

    final detailsOpacity = ((percentage - 0.7) / 0.3).clamp(0.0, 1.0);

    var minPadding = height * 0.02;
    var maxPadding =
        MediaQuery.of(context).padding.top -
        kToolbarHeight +
        MediaQuery.of(context).size.width * 0.05;
    final currentPadding =
        lerpDouble(minPadding, maxPadding, normalizedPercentage)!;

    return GlassContainer(
      color: Colors.black.withValues(alpha: 0.3),
      borderColor: Colors.transparent,
      blur: 45.0,
      elevation: 0.0,
      borderWidth: 0.0,
      borderRadius: BorderRadius.circular(height * 0.02),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: currentPadding,
              bottom:
                  MediaQuery.of(context).padding.bottom -
                  kBottomNavigationBarHeight +
                  height * 0.025,
              right: MediaQuery.of(context).size.width * 0.05,
              left: MediaQuery.of(context).size.width * 0.05,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Opacity(
                  opacity: progressBarOpacity,
                  child: Container(
                    height: topButtonsHeight,
                    margin: EdgeInsets.symmetric(vertical: height * 0.0125),
                    child: Row(
                      children: [
                        AndroidVolumeWidget(),

                        const Spacer(),

                        IconButton(
                          onPressed: () async {
                            Provider.of<AbstractAppStateProvider>(
                              context,
                              listen: false,
                            ).miniPlayerController.animateToHeight(
                              state: PanelState.min,
                            );
                          },
                          icon: Icon(
                            FluentIcons.down,
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
                      ],
                    ),
                  ),
                ),

                Container(
                  width: double.infinity,
                  height: height * 0.4,
                  alignment: Alignment.topCenter,
                  child: ValueListenableBuilder(
                    valueListenable: _listView,
                    builder: (context, value, child) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child:
                            value
                                ? QueueTab(
                                  key: const ValueKey<int>(1),
                                  itemScrollController: itemScrollController,
                                )
                                : DetailsTab(
                                  key: const ValueKey<int>(2),
                                  miniPlayerController:
                                      appStateProvider.miniPlayerController,
                                  opacity: detailsOpacity,
                                ),
                      );
                    },
                  ),
                ),

                Opacity(
                  opacity: progressBarOpacity,
                  child: SizedBox(height: height * 0.05),
                ),

                const Spacer(),

                Opacity(
                  opacity: progressBarOpacity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      buildShuffleButton(context),

                      _buildListButton(context),

                      buildRepeatButton(context),
                    ],
                  ),
                ),

                const Spacer(),

                Opacity(
                  opacity: progressBarOpacity,
                  child: SizedBox(height: height * 0.025),
                ),

                // ProgressBar
                Opacity(
                  opacity: progressBarOpacity,
                  child:
                      sidePanelsOpacity > 0.99
                          ? FutureBuilder(
                            future: audioProvider.getDuration(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
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

                                    progressBarColor:
                                        appStateProvider.colors.first,
                                    baseBarColor: appStateProvider.colors.last
                                        .withValues(alpha: 0.4),
                                    thumbColor: Colors.white,
                                    barHeight: 4.0,
                                    thumbRadius: 7.0,
                                    timeLabelLocation: TimeLabelLocation.above,
                                    timeLabelTextStyle:
                                        MusicPlayerTheme.getTheme(
                                          context,
                                          context.read<Scaler>(),
                                        ).textTheme.bodyMedium!.copyWith(
                                          color: Colors.white,
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
                          : const Center(
                            child: LinearProgressIndicator(
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                ),

                const Spacer(),

                Opacity(
                  opacity: progressBarOpacity,
                  child: SizedBox(height: height * 0.025),
                ),

                // Player Controls - Previous, Play/Pause, Next
                Opacity(
                  opacity: progressBarOpacity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: width * 0.9,
                        child: _buildPlayerButtons(audioProvider),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height:
                      MediaQuery.of(context).size.height * 0.1 +
                      MediaQuery.of(context).padding.bottom -
                      kBottomNavigationBarHeight +
                      MediaQuery.of(context).size.height * 0.05,
                ),
              ],
            ),
          ),

          if (progressBarOpacity > 0.75)
            _buildLyricsForAndroid(progressBarOpacity),
        ],
      ),
    );
  }

  Widget _buildLyricsForAndroid(double progressBarOpacity) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return MiniPlayer(
      minHeight:
          MediaQuery.of(context).size.height * 0.1 +
          MediaQuery.of(context).padding.bottom -
          kBottomNavigationBarHeight +
          height * 0.05,
      maxHeight: MediaQuery.of(context).size.height,
      minWidth: MediaQuery.of(context).size.width * 0.95,
      maxWidth: MediaQuery.of(context).size.width,
      borderRadius: BorderRadius.circular(height * 0.02),
      controller: _miniPlayerController,
      builder: (_, percentage) {
        return Opacity(
          opacity: progressBarOpacity,
          child: GlassContainer(
            color: Colors.black.withValues(alpha: 0.1),
            borderColor: Colors.transparent,
            blur: 45.0,
            elevation: 0.0,
            borderWidth: 0.0,
            borderRadius: BorderRadius.circular(height * 0.02),
            padding: EdgeInsets.only(
              top: percentage < 0.35 ? 0 : MediaQuery.of(context).padding.top,
              bottom:
                  percentage < 0.35
                      ? MediaQuery.of(context).padding.bottom -
                          kBottomNavigationBarHeight +
                          height * 0.025
                      : 0,
            ),
            child: Column(
              children: [
                IconButton(
                  onPressed: () async {
                    if (percentage < 0.35) {
                      _miniPlayerController.animateToHeight(
                        state: PanelState.max,
                      );
                    } else {
                      _miniPlayerController.animateToHeight(
                        state: PanelState.min,
                      );
                    }
                  },
                  icon: Icon(
                    percentage < 0.35 ? FluentIcons.up : FluentIcons.down,
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
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding:
                        percentage < 0.35
                            ? EdgeInsets.symmetric(horizontal: width * 0.05)
                            : EdgeInsets.all(width * 0.05),
                    child: IgnorePointer(
                      ignoring: percentage < 0.35,
                      child: LyricsTab(oneLine: percentage < 0.75),
                    ),
                  ),
                ),
                if (percentage > 0.35) ...[
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom,
                    ),
                    child: _buildPlayerButtons(audioProvider),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListButton(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    return IconButton(
      onPressed: () {
        _listView.value = !_listView.value;
        Future.delayed(const Duration(milliseconds: 400), () {
          if (itemScrollController.hasClients) {
            debugPrint("Jumping to current song index in queue");
            int currentSongIndex = audioProvider.currentIndexInNonShuffled;
            if (currentSongIndex > 15) {
              itemScrollController.jumpTo(
                height * 0.075 * (currentSongIndex - 10),
              );
            }
            itemScrollController.animateTo(
              height * 0.075 * currentSongIndex,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          }
        });
      },
      icon: Icon(
        FluentIcons.listView,
        color: Colors.white,
        size: height * 0.02,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(1, 2),
            blurRadius: 7,
          ),
        ],
      ),
    );
  }

  @override
  Widget buildPlayPauseButton(BuildContext context, {bool expanded = false}) {
    var height = MediaQuery.of(context).size.height;
    return ValueListenableBuilder(
      valueListenable: audioProvider.playingNotifier,
      builder: (context, value, child) {
        return IconButton(
          onPressed: () async {
            if (audioProvider.playingNotifier.value) {
              await audioProvider.pause();
            } else {
              await audioProvider.play();
            }
          },
          icon: Icon(
            value ? FluentIcons.pause : FluentIcons.play,
            color: Colors.white,
            size: height * 0.03,
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
  Widget buildNextButton(BuildContext context, {bool expanded = false}) {
    var height = MediaQuery.of(context).size.height;
    return IconButton(
      onPressed: () async {
        debugPrint("next");
        return await audioProvider.skipToNext();
      },
      icon: Icon(
        FluentIcons.next,
        color: Colors.white,
        size: height * 0.03,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(1, 2),
            blurRadius: 7,
          ),
        ],
      ),
    );
  }

  @override
  Widget buildPreviousButton(BuildContext context, {bool expanded = false}) {
    var height = MediaQuery.of(context).size.height;
    return IconButton(
      onPressed: () => audioProvider.skipToPrevious(),
      icon: Icon(
        FluentIcons.previous,
        color: Colors.white,
        size: height * 0.03,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(1, 2),
            blurRadius: 7,
          ),
        ],
      ),
    );
  }

  @override
  Widget buildShuffleButton(BuildContext context, {bool expanded = false}) {
    var height = MediaQuery.of(context).size.height;
    return ValueListenableBuilder(
      valueListenable: audioProvider.shuffleNotifier,
      builder: (context, shuffle, child) {
        return IconButton(
          onPressed: () {
            audioProvider.setShuffle(!audioProvider.shuffleNotifier.value);
          },
          icon: Icon(
            shuffle == false ? FluentIcons.shuffleOff : FluentIcons.shuffleOn,
            size: height * 0.02,
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
    var height = MediaQuery.of(context).size.height;
    return ValueListenableBuilder(
      valueListenable: audioProvider.repeatNotifier,
      builder: (context, value, child) {
        return IconButton(
          onPressed: () {
            audioProvider.setRepeat(!audioProvider.repeatNotifier.value);
          },
          icon: Icon(
            value == false ? FluentIcons.repeatOff : FluentIcons.repeatOn,
            size: height * 0.02,
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

  Widget _buildPlayerButtons(AudioProvider audioProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        buildPreviousButton(context),
        buildPlayPauseButton(context),
        buildNextButton(context),
      ],
    );
  }
}
