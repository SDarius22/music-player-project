import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/providers/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/animated_background.dart';
import 'package:music_player_frontend/utils/miniplayer/miniplayer.dart';
import 'package:provider/provider.dart';

class SongPlayerWidget extends StatefulWidget{
  const SongPlayerWidget({super.key});

  @override
  State<SongPlayerWidget> createState() => _SongPlayerWidgetState();
}


class _SongPlayerWidgetState extends State<SongPlayerWidget> with TickerProviderStateMixin {
  ValueNotifier<bool> likedNotifier = ValueNotifier<bool>(false);
  final MiniPlayerController _miniPlayerController = MiniPlayerController();
  final ScrollController _itemScrollController = ScrollController();
  final AnimatedMeshGradientController _gradientController = AnimatedMeshGradientController();

  double _getMinHeight() {
    throw UnimplementedError();
  }

  double _getMaxHeight() {
    throw UnimplementedError();
  }

  double _getMinWidth() {
    throw UnimplementedError();
  }

  double _getMaxWidth() {
    throw UnimplementedError();
  }
  
  double _getItemExtent() {
    throw UnimplementedError();
  }

  Widget _buildMinimizedPlayerContent(double percentage) {
    throw UnimplementedError();
  }

  Widget _buildMaximizedPlayerContent(double percentage) {
    throw UnimplementedError();
  }

  Widget _buildPlayPauseButton({bool expanded = false}) {
    throw UnimplementedError();
  }

  Widget _buildNextButton({bool expanded = false}) {
    throw UnimplementedError();
  }

  Widget _buildPreviousButton({bool expanded = false}) {
    throw UnimplementedError();
  }

  Widget _buildShuffleButton({bool expanded = false}) {
    throw UnimplementedError();
  }

  Widget _buildRepeatButton({bool expanded = false}) {
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AbstractAudioProvider>(
      builder: (_, audioProvider, __) {
        debugPrint("Building SongPlayerWidget, current song: ${audioProvider.currentSong?.name}");
        if (audioProvider.currentQueue.isEmpty || audioProvider.currentSong == null) {
          debugPrint("Queue is empty, not showing player");
          return const SizedBox.shrink();
        }
        final ValueNotifier<double> playerExpandProgress = ValueNotifier<double>(_getMaxHeight());
        return MiniPlayer(
          valueNotifier: playerExpandProgress,
          minHeight: _getMinHeight(),
          maxHeight: _getMaxHeight(),
          minWidth: _getMinWidth(),
          maxWidth: _getMaxWidth(),
          controller: _miniPlayerController,
          elevation: 4,
          curve: Curves.easeOut,
          tapToCollapse: false,
          duration: const Duration(milliseconds: 500),
          builder: (_, percentage) {
            final bool minimized = percentage < 0.25;

            if (minimized) {
              return _buildMinimizedPlayer(percentage);
            }

            if (_itemScrollController.hasClients) {
              int currentSongIndex = audioProvider.currentIndexInNormal;
              Future.delayed(const Duration(milliseconds: 500), () {
                try {
                  _itemScrollController.animateTo(_getItemExtent() * currentSongIndex, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
                }
                catch (e) {
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

  Widget _buildMinimizedPlayer(double percentage){

    return AnimatedBackground(
      key: const Key("minimizedPlayer"),
      height: _getMinHeight(),
      width: _getMinWidth(),
      alignment: Alignment.centerLeft,
      controller: _gradientController,
      child: _buildMinimizedPlayerContent(percentage),
    );
  }

  Widget _buildMaximizedPlayer(double percentage){

    return AnimatedBackground(
      key: const Key("maximizedPlayer"),
      height: _getMaxHeight(),
      width: _getMaxWidth(),
      alignment: Alignment.center,
      controller: _gradientController,
      child: _buildMaximizedPlayerContent(percentage),
    );
  }

  Widget _buildPlayerButtons({bool expanded = false}){

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        _buildShuffleButton(expanded: expanded),
        _buildPreviousButton(expanded: expanded),
        _buildPlayPauseButton(expanded: expanded),
        _buildNextButton(expanded: expanded),
        _buildRepeatButton(expanded: expanded),

      ],
    );

  }
}
