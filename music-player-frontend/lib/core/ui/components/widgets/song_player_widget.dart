import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/tabs/details_tab.dart';
import 'package:music_player_frontend/core/ui/components/tabs/lyrics_tab.dart';
import 'package:music_player_frontend/core/ui/components/tabs/queue_tab.dart';
import 'package:music_player_frontend/core/ui/components/widgets/volume_widget.dart';
import 'package:music_player_frontend/local_libs/audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';
import 'package:music_player_frontend/local_libs/multivaluelistenablebuilder/mvlb.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

class SongPlayerWidget extends StatefulWidget {
  const SongPlayerWidget({super.key});

  @override
  State<SongPlayerWidget> createState() => _SongPlayerWidgetState();
}

class _SongPlayerWidgetState extends State<SongPlayerWidget>
    with TickerProviderStateMixin {
  ValueNotifier<bool> likedNotifier = ValueNotifier<bool>(false);
  final ScrollController itemScrollController = ScrollController();
  late AbstractAppStateProvider appStateProvider;
  late AudioProvider audioProvider;
  final MiniPlayerController _lyricsPlayerController = MiniPlayerController();
  final ValueNotifier<bool> _listView = ValueNotifier<bool>(false);
  double detailsOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    appStateProvider = context.read<AbstractAppStateProvider>();
    audioProvider = context.read<AudioProvider>();
  }

  bool get _isNotDesktop =>
      !ResponsiveBreakpoints.of(context).isDesktop &&
      !ResponsiveBreakpoints.of(context).equals("4K");

  bool isMinimized(double percentage) {
    if (_isNotDesktop) return percentage < 0.45;
    return percentage < 0.25;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (_, audioProvider, _) {
        if (audioProvider.currentSong == null) {
          debugPrint("Not showing player");
          return const SizedBox.shrink();
        }

        debugPrint(
          "Building SongPlayerWidget, current song: ${audioProvider.currentSong!.name}",
        );
        final ValueNotifier<double> playerExpandProgress =
            ValueNotifier<double>(getMinHeight(context));

        final controller =
            Provider.of<AbstractAppStateProvider>(
              context,
              listen: false,
            ).miniPlayerController;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final height = MediaQuery.of(context).size.height;
          final width = MediaQuery.of(context).size.width;
          if (height < 200 || width < 200) {
            debugPrint("Screen too small for mini player, not showing player");
            return;
          }
          var animateTo =
              Provider.of<AbstractAppStateProvider>(
                        context,
                        listen: false,
                      ).opacityNotifier.value >
                      0.8
                  ? PanelState.min
                  : PanelState.max;
          controller.animateToHeight(state: animateTo);
        });

        return LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = getMinHeight(context);
            final maxHeight = getMaxHeight(context);
            final minWidth = getMinWidth(context);
            final maxWidth = getMaxWidth(context);
            return MiniPlayer(
              valueNotifier: playerExpandProgress,
              minHeight: minHeight,
              maxHeight: maxHeight,
              minWidth: minWidth,
              maxWidth: maxWidth,
              borderRadius: getBorderRadius(context),
              maxBorderRadius: getBorderRadius(context),
              controller: controller,
              elevation: 0.0,
              curve: Curves.easeOut,
              tapToCollapse: false,
              duration: const Duration(milliseconds: 500),
              backgroundColor: Colors.transparent,
              backgroundBoxShadow: Colors.transparent,
              builder: (_, percentage) {
                final bool minimized = isMinimized(percentage);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final appStateProvider =
                      Provider.of<AbstractAppStateProvider>(
                        context,
                        listen: false,
                      );
                  final newOpacity = 1 - (percentage * 1.1).clamp(0.0, 1.0);
                  if (appStateProvider.opacityNotifier.value != newOpacity) {
                    appStateProvider.opacityNotifier.value = newOpacity;
                  }
                });

                if (minimized) {
                  return buildMinimizedPlayerContent(context, percentage);
                }

                return buildMaximizedPlayerContent(context, percentage);
              },
            );
          },
        );
      },
    );
  }

  double getMinHeight(BuildContext context) {
    if (_isNotDesktop) {
      return MediaQuery.of(context).size.height * 0.075;
    }
    return MediaQuery.of(context).size.height * 0.1;
  }

  double getMaxHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  double getMinWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  double getMaxWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  double getItemExtent(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.1;
  }

  BorderRadius getBorderRadius(BuildContext context) {
    return BorderRadius.circular(MediaQuery.of(context).size.height * 0.015);
  }

  Widget buildMinimizedPlayerContent(BuildContext context, double percentage) {
    if (_isNotDesktop) {
      return _buildMobileMinimizedContent(context, percentage);
    }
    return _buildDesktopMinimizedContent(context, percentage);
  }

  Widget buildMaximizedPlayerContent(BuildContext context, double percentage) {
    if (_isNotDesktop) {
      return _buildMobileMaximizedContent(context, percentage);
    }
    return _buildDesktopMaximizedContent(context, percentage);
  }

  Widget _buildDesktopMinimizedContent(
    BuildContext context,
    double percentage,
  ) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    double minLeftMargin = 0;
    double maxLeftMargin = width * 0.725;
    double imageLeftMargin =
        lerpDouble(minLeftMargin, maxLeftMargin, percentage) ?? 0.0;
    if (imageLeftMargin < 0) {
      imageLeftMargin = 0;
    }

    double normalized = (1.0 - (percentage / 0.25).clamp(0.0, 1.0));
    double progressBarOpacity = normalized;

    detailsOpacity = 0.0;

    return GlassContainer(
      color: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      borderWidth: 0.0,
      blur: 45.0,
      elevation: 3.0,
      borderRadius: getBorderRadius(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            alignment: Alignment.center,
            margin: EdgeInsets.only(left: imageLeftMargin),
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: getBorderRadius(context),
            ),
            child: DetailsTab(
              currentSong: audioProvider.currentSong!,
              miniPlayerController: appStateProvider.miniPlayerController,
              opacity: detailsOpacity,
            ),
          ),

          Opacity(
            opacity: progressBarOpacity,
            child: Container(
              height: height * 0.15,
              width: width * 0.2,
              margin: EdgeInsets.only(left: width * 0.01),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audioProvider.currentSong!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                    audioProvider.currentSong!.artist.target?.name ??
                        'Unknown Artist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              width: width * 0.3,
              height: height * 0.15,
              child: const IgnorePointer(
                ignoring: true,
                child: LyricsTab(oneLine: true),
              ),
            ),
          ),

          const Spacer(),

          Opacity(
            opacity: progressBarOpacity,
            child: SizedBox(
              width: width * 0.25,
              height: height * 0.15,
              child: _buildPlayerButtons(audioProvider, expanded: true),
            ),
          ),

          Opacity(
            opacity: progressBarOpacity,
            child: SizedBox(
              width: width * 0.05,
              height: height * 0.15,
              child: IconButton(
                onPressed:
                    () => Provider.of<AbstractAppStateProvider>(
                      context,
                      listen: false,
                    ).miniPlayerController.animateToHeight(
                      state: PanelState.max,
                    ),
                icon: Icon(FluentIcons.maximize, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMinimizedContent(BuildContext context, double percentage) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    double imageLeftMargin =
        lerpDouble(0.0, width * 0.05, percentage / 0.45) ?? 0.0;
    if (imageLeftMargin < 0) imageLeftMargin = 0;
    double imageTopMargin =
        lerpDouble(0.0, width * 0.05, percentage / 0.45) ?? 0.0;
    if (imageTopMargin < 0) imageTopMargin = 0;

    double borderRadius = lerpDouble(height * 0.015, 0.0, percentage) ?? 0.0;

    double opacity = (1.0 - (percentage / 0.45).clamp(0.0, 1.0));

    detailsOpacity = 0.0;

    return GlassContainer(
      color: Colors.black.withValues(alpha: 0.3),
      borderColor: Colors.transparent,
      borderWidth: 0.0,
      blur: 45.0,
      elevation: 3.0,
      borderRadius: getBorderRadius(context),
      child: Row(
        children: [
          Container(
            alignment: Alignment.center,
            margin: EdgeInsets.only(
              left: imageLeftMargin,
              top: imageTopMargin,
              bottom: imageTopMargin,
            ),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: DetailsTab(
              currentSong: audioProvider.currentSong!,
              miniPlayerController: appStateProvider.miniPlayerController,
              opacity: detailsOpacity,
            ),
          ),
          Opacity(
            opacity: opacity,
            child: Container(
              height: height * 0.15,
              width: width * 0.3,
              margin: EdgeInsets.only(left: width * 0.01),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audioProvider.currentSong!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                    audioProvider.currentSong!.artist.target?.name ??
                        'Unknown Artist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
            opacity: opacity,
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

  Widget _buildDesktopMaximizedContent(
    BuildContext context,
    double percentage,
  ) {
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

    final showSidePanels = normalizedPercentage > 0.8;
    final sidePanelsOpacity = ((normalizedPercentage - 0.8) / 0.2).clamp(
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
            )!;

    detailsOpacity = ((percentage - 0.7) / 0.3).clamp(0.0, 1.0);

    if (sidePanelsOpacity > 0.99) {
      if (itemScrollController.hasClients) {
        debugPrint("Jumping to current song index in queue");
        int currentSongIndex = audioProvider.currentIndexInNonShuffled;
        if (currentSongIndex > 15) {
          itemScrollController.jumpTo(height * 0.085 * (currentSongIndex - 10));
        }
        itemScrollController.animateTo(
          height * 0.085 * currentSongIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }

    return GlassContainer(
      color: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      blur: 45.0,
      borderRadius: getBorderRadius(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Lyrics
                if (showSidePanels)
                  Opacity(
                    opacity: sidePanelsOpacity,
                    child: Container(
                      width: width * 0.3,
                      height: width * 0.3,
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.01,
                        vertical: height * 0.01,
                      ),
                      child: const LyricsTab(),
                    ),
                  ),

                const Spacer(),

                // Album Art
                Container(
                  alignment: Alignment.center,
                  constraints: BoxConstraints(maxWidth: width * 0.325),
                  margin: EdgeInsets.only(right: imageRightMargin),
                  child: DetailsTab(
                    currentSong: audioProvider.currentSong!,
                    miniPlayerController: appStateProvider.miniPlayerController,
                    opacity: detailsOpacity,
                  ),
                ),

                const Spacer(),
                // Queue
                if (showSidePanels)
                  Opacity(
                    opacity: sidePanelsOpacity,
                    child: Container(
                      width: width * 0.3,
                      height: width * 0.3,
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.01,
                        vertical: height * 0.01,
                      ),
                      child: QueueTab(
                        itemScrollController: itemScrollController,
                      ),
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
                    sidePanelsOpacity > 0.99
                        ? ValueListenableBuilder(
                          valueListenable: audioProvider.totalDurationNotifier,
                          builder: (context, totalDuration, _) {
                            return ValueListenableBuilder(
                              valueListenable: audioProvider.sliderNotifier,
                              builder: (context, value, child) {
                                return ProgressBar(
                                  progress: Duration(milliseconds: value),
                                  buffered: Duration(
                                    seconds:
                                        audioProvider
                                            .bufferedPositionNotifier
                                            .value,
                                  ),
                                  total: totalDuration,
                                  progressBarColor:
                                      appStateProvider.colors.first,
                                  baseBarColor: appStateProvider.colors.last
                                      .withValues(alpha: 0.25),
                                  bufferedBarColor: appStateProvider.colors.last
                                      .withValues(alpha: 0.5),
                                  thumbColor: Colors.white,
                                  barHeight: 4.0,
                                  thumbRadius: 7.0,
                                  timeLabelLocation: TimeLabelLocation.sides,
                                  timeLabelTextStyle: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color: Colors.white,
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
                        : const Center(
                          child: LinearProgressIndicator(
                            color: Colors.white,
                            backgroundColor: Colors.white24,
                          ),
                        ),
              ),
            ),
          ),

          // Player Controls
          Opacity(
            opacity: progressBarOpacity,
            child: SizedBox(
              width: width * 0.9,
              height: buttonsHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const VolumeWidget(),

                  const Spacer(),

                  SizedBox(
                    width: width * 0.5,
                    child: _buildPlayerButtons(audioProvider, expanded: true),
                  ),

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
                      FluentIcons.minimize,
                      color: Colors.white,
                      size: 24,
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

  Widget _buildMobileMaximizedContent(BuildContext context, double percentage) {
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

    detailsOpacity = ((percentage - 0.7) / 0.3).clamp(0.0, 1.0);

    var minPadding = height * 0.02;
    var maxPadding = height * 0.025;
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
              bottom: MediaQuery.of(context).padding.bottom + height * 0.025,
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
                        VolumeWidget(),

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
                            size: 24,
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
                                  currentSong: audioProvider.currentSong!,
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
                  child: SizedBox(height: height * 0.025),
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
                          ? ValueListenableBuilder(
                            valueListenable:
                                audioProvider.totalDurationNotifier,
                            builder: (context, totalDuration, _) {
                              return ValueListenableBuilder(
                                valueListenable: audioProvider.sliderNotifier,
                                builder: (context, value, child) {
                                  return ProgressBar(
                                    progress: Duration(milliseconds: value),
                                    total: totalDuration,
                                    progressBarColor:
                                        appStateProvider.colors.first,
                                    baseBarColor: appStateProvider.colors.last
                                        .withValues(alpha: 0.4),
                                    thumbColor: Colors.white,
                                    barHeight: 4.0,
                                    thumbRadius: 7.0,
                                    timeLabelLocation: TimeLabelLocation.above,
                                    timeLabelTextStyle: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(color: Colors.white),
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
                  child: SizedBox(height: height * 0.05),
                ),

                // Player Controls - Previous, Play/Pause, Next
                Opacity(
                  opacity: progressBarOpacity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: width * 0.8,
                        child: _buildPlayerButtons(audioProvider),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height:
                      MediaQuery.of(context).size.height * 0.1 +
                      MediaQuery.of(context).padding.bottom,
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
          MediaQuery.of(context).padding.bottom,
      maxHeight: MediaQuery.of(context).size.height,
      minWidth: MediaQuery.of(context).size.width,
      maxWidth: MediaQuery.of(context).size.width,
      borderRadius: getBorderRadius(context),
      controller: _lyricsPlayerController,
      builder: (_, percentage) {
        return Opacity(
          opacity: progressBarOpacity,
          child: GlassContainer(
            color: Colors.black.withValues(alpha: 0.1),
            borderColor: Colors.transparent,
            blur: 45.0,
            elevation: 0.0,
            borderWidth: 0.0,
            borderRadius: getBorderRadius(context),
            padding: EdgeInsets.only(
              top: percentage < 0.35 ? 0 : MediaQuery.of(context).padding.top,
              bottom:
                  percentage < 0.35
                      ? MediaQuery.of(context).padding.bottom + height * 0.025
                      : MediaQuery.of(context).padding.bottom + width * 0.05,
            ),
            child: Column(
              children: [
                IconButton(
                  onPressed: () async {
                    if (percentage < 0.35) {
                      _lyricsPlayerController.animateToHeight(
                        state: PanelState.max,
                      );
                    } else {
                      _lyricsPlayerController.animateToHeight(
                        state: PanelState.min,
                      );
                    }
                  },
                  icon: Icon(
                    percentage < 0.35 ? FluentIcons.up : FluentIcons.down,
                    color: Colors.white,
                    size: 24,
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
                    child: _buildPlayerButtons(audioProvider, expanded: true),
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
        size: 20,
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

  Widget buildPlayPauseButton(BuildContext context, {bool expanded = false}) {
    return MultiValueListenableBuilder(
      valueListenables: [
        audioProvider.processingState,
        audioProvider.playingNotifier,
      ],
      builder: (context, values, child) {
        final ProcessingState processingState = values[0] as ProcessingState;
        final bool isPlaying = values[1] as bool;

        final bool showBufferingIndicator =
            processingState == ProcessingState.loading ||
            (processingState == ProcessingState.buffering &&
                // On web, just_audio may report buffering while playback is still advancing.
                (!kIsWeb || !isPlaying));

        if (showBufferingIndicator) {
          debugPrint(
            "Processing state is ${processingState == ProcessingState.loading ? "loading" : "buffering"}, showing progress indicator",
          );
          return Container(
            width: 28,
            height: 28,
            padding: const EdgeInsets.all(4),
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          );
        }

        final bool showPause =
            isPlaying && processingState != ProcessingState.completed;

        return IconButton(
          onPressed: () {
            if (isPlaying) {
              audioProvider.pause();
            } else {
              if (processingState == ProcessingState.completed) {
                audioProvider.seek(Duration.zero);
              }
              audioProvider.play();
            }
          },
          icon: Icon(
            showPause ? FluentIcons.pause : FluentIcons.play,
            color: Colors.white,
            size: 28,
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

  Widget buildNextButton(BuildContext context, {bool expanded = false}) {
    return IconButton(
      onPressed: () async {
        debugPrint("next");
        return await audioProvider.skipToNext();
      },
      icon: Icon(
        FluentIcons.next,
        color: Colors.white,
        size: 28,
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

  Widget buildPreviousButton(BuildContext context, {bool expanded = false}) {
    return IconButton(
      onPressed: () => audioProvider.skipToPrevious(),
      icon: Icon(
        FluentIcons.previous,
        color: Colors.white,
        size: 28,
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
            size: 28,
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

  Widget buildRepeatButton(BuildContext context, {bool expanded = false}) {
    return ValueListenableBuilder(
      valueListenable: audioProvider.repeatNotifier,
      builder: (context, value, child) {
        return IconButton(
          onPressed: () {
            audioProvider.setRepeat(!audioProvider.repeatNotifier.value);
          },
          icon: Icon(
            value == false ? FluentIcons.repeatOff : FluentIcons.repeatOn,
            size: 24,
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

  Widget _buildPlayerButtons(
    AudioProvider audioProvider, {
    bool expanded = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (expanded) buildShuffleButton(context),
        buildPreviousButton(context),
        buildPlayPauseButton(context),
        buildNextButton(context),
        if (expanded) buildRepeatButton(context),
      ],
    );
  }
}
