import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
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
  final ScrollController itemScrollController = ScrollController();
  late MemoryImage cachedCoverArt;

  void _getCoverArtImage(Song currentSong) {
    cachedCoverArt = MemoryImage(currentSong.coverArt);
  }

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

  BorderRadius getBorderRadius(BuildContext context) {
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
          "Building SongPlayerWidget, current song: ${audioProvider.currentSong.name}",
        );
        if (audioProvider.currentQueue.isEmpty) {
          debugPrint("Queue is empty, not showing player");
          return const SizedBox.shrink();
        }
        _getCoverArtImage(audioProvider.currentSong);
        final ValueNotifier<double> playerExpandProgress =
            ValueNotifier<double>(getMinHeight(context));

        final controller =
            Provider.of<AbstractAppStateProvider>(
              context,
              listen: false,
            ).miniPlayerController;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.animateToHeight(state: PanelState.min);
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
              elevation: 3.0,
              curve: Curves.easeOut,
              tapToCollapse: false,
              duration: const Duration(milliseconds: 500),
              builder: (_, percentage) {
                final bool minimized = percentage < 0.25;
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
                  return _buildMinimizedPlayer(percentage);
                }

                return _buildMaximizedPlayer(percentage);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMinimizedPlayer(double percentage) {
    return GlassContainer(
      color: Colors.black.withValues(alpha: 0.2),
      borderColor: Colors.transparent,
      borderWidth: 0.0,
      blur: 45.0,
      elevation: 3.0,
      borderRadius: getBorderRadius(context),
      child: buildMinimizedPlayerContent(context, percentage),
    );
  }

  Widget _buildMaximizedPlayer(double percentage) {
    return GlassContainer(
      color: Colors.black.withValues(alpha: 0.1),
      borderColor: Colors.transparent,
      blur: 45.0,
      borderRadius: getBorderRadius(context),
      child: buildMaximizedPlayerContent(context, percentage),
    );
  }
}
