import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/animated_background.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';
import 'package:provider/provider.dart';

class SongPlayerWidget extends StatefulWidget {
  const SongPlayerWidget({super.key});

  @override
  State<SongPlayerWidget> createState() => SongPlayerWidgetState();
}

class SongPlayerWidgetState extends State<SongPlayerWidget>
    with TickerProviderStateMixin {
  ValueNotifier<bool> likedNotifier = ValueNotifier<bool>(false);
  final MiniPlayerController miniPlayerController = MiniPlayerController();
  final ScrollController itemScrollController = ScrollController();
  final AnimatedMeshGradientController gradientController =
      AnimatedMeshGradientController();

  double getMinHeight(BuildContext context) {
    throw UnimplementedError();
  }

  double getMaxHeight(BuildContext context) {
    throw UnimplementedError();
  }

  double getMinWidth(BuildContext context) {
    throw UnimplementedError();
  }

  double getMaxWidth(BuildContext context) {
    throw UnimplementedError();
  }

  double getItemExtent(BuildContext context) {
    throw UnimplementedError();
  }

  Widget buildMinimizedPlayerContent(BuildContext context, double percentage) {
    throw UnimplementedError();
  }

  Widget buildMaximizedPlayerContent(BuildContext context, double percentage) {
    throw UnimplementedError();
  }

  Widget buildPlayPauseButton(BuildContext context, {bool expanded = false}) {
    throw UnimplementedError();
  }

  Widget buildNextButton(BuildContext context, {bool expanded = false}) {
    throw UnimplementedError();
  }

  Widget buildPreviousButton(BuildContext context, {bool expanded = false}) {
    throw UnimplementedError();
  }

  Widget buildShuffleButton(BuildContext context, {bool expanded = false}) {
    throw UnimplementedError();
  }

  Widget buildRepeatButton(BuildContext context, {bool expanded = false}) {
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AbstractAudioProvider>(
      builder: (_, audioProvider, __) {
        debugPrint(
          "Building SongPlayerWidget, current song: ${audioProvider.audioService.currentSong?.name}",
        );
        if (audioProvider.audioService.audioSettings.currentQueue.isEmpty ||
            audioProvider.audioService.currentSong == null) {
          debugPrint("Queue is empty, not showing player");
          return const SizedBox.shrink();
        }
        final ValueNotifier<double> playerExpandProgress =
            ValueNotifier<double>(getMaxHeight(context));
        return MiniPlayer(
          valueNotifier: playerExpandProgress,
          minHeight: getMinHeight(context),
          maxHeight: getMaxHeight(context),
          minWidth: getMinWidth(context),
          maxWidth: getMaxWidth(context),
          controller: miniPlayerController,
          elevation: 4,
          curve: Curves.easeOut,
          tapToCollapse: false,
          duration: const Duration(milliseconds: 500),
          builder: (_, percentage) {
            final bool minimized = percentage < 0.25;

            if (minimized) {
              return _buildMinimizedPlayer(percentage);
            }

            if (itemScrollController.hasClients) {
              int currentSongIndex =
                  audioProvider
                      .audioService
                      .audioSettings
                      .currentIndexInNonShuffled;
              Future.delayed(const Duration(milliseconds: 500), () {
                try {
                  itemScrollController.animateTo(
                    getItemExtent(context) * currentSongIndex,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  );
                } catch (e) {
                  debugPrint("Error animating to current song index: $e");
                }
              });
            }

            return _buildMaximizedPlayer(percentage);
          },
        );
      },
    );
  }

  Widget _buildMinimizedPlayer(double percentage) {
    return AnimatedBackground(
      key: const Key("minimizedPlayer"),
      height: getMinHeight(context),
      width: getMinWidth(context),
      alignment: Alignment.centerLeft,
      controller: gradientController,
      child: buildMinimizedPlayerContent(context, percentage),
    );
  }

  Widget _buildMaximizedPlayer(double percentage) {
    return AnimatedBackground(
      key: const Key("maximizedPlayer"),
      height: getMaxHeight(context),
      width: getMaxWidth(context),
      alignment: Alignment.center,
      controller: gradientController,
      child: buildMaximizedPlayerContent(context, percentage),
    );
  }
}
