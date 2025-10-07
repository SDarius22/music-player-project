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
        return MiniPlayer(
          valueNotifier: playerExpandProgress,
          minHeight: getMinHeight(context),
          maxHeight: getMaxHeight(context),
          minWidth: getMinWidth(context),
          maxWidth: getMaxWidth(context),
          borderRadius: BorderRadius.circular(
            MediaQuery.of(context).size.height * 0.015,
          ),
          maxBorderRadius: BorderRadius.circular(
            MediaQuery.of(context).size.height * 0.015,
          ),
          controller:
              Provider.of<AbstractAppStateProvider>(
                context,
                listen: false,
              ).miniPlayerController,
          elevation: 3.0,
          curve: Curves.easeOut,
          tapToCollapse: false,
          duration: const Duration(milliseconds: 500),
          builder: (_, percentage) {
            final bool minimized = percentage < 0.25;

            if (minimized) {
              return _buildMinimizedPlayer(percentage);
            }

            return _buildMaximizedPlayer(percentage);
          },
        );
      },
    );
  }

  Widget _buildMinimizedPlayer(double percentage) {
    return GlassContainer(
      color: Colors.black.withValues(alpha: 0.2),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.60),
          Colors.indigoAccent.withOpacity(0.6),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(
        MediaQuery.of(context).size.height * 0.015,
      ),
      blur: 45.0,
      borderWidth: 1.5,
      elevation: 3.0,
      shadowColor: Colors.black.withOpacity(0.10),
      child: buildMinimizedPlayerContent(context, percentage),
    );
  }

  Widget _buildMaximizedPlayer(double percentage) {
    return GlassContainer(
      color: Colors.black.withOpacity(0.2),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.60),
          Colors.indigoAccent.withOpacity(0.6),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(
        MediaQuery.of(context).size.height * 0.015,
      ),
      blur: 45.0,
      borderWidth: 1.5,
      elevation: 3.0,
      shadowColor: Colors.black.withOpacity(0.20),
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.01,
        vertical: MediaQuery.of(context).size.height * 0.02,
      ),
      child: buildMaximizedPlayerContent(context, percentage),
    );
  }
}
