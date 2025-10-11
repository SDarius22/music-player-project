import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/tabs/details_tab.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';
import 'package:provider/provider.dart';

class DetailsTab extends AbstractDetailsTab {
  final MiniPlayerController miniPlayerController;

  const DetailsTab({
    super.key,
    required this.miniPlayerController,
    required super.opacity,
  });

  @override
  Widget buildDetailsContent(BuildContext context) {
    return Consumer<AbstractAudioProvider>(
      builder: (_, audioProvider, __) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: Colors.black,
            borderRadius: BorderRadius.circular(
              MediaQuery.of(context).size.height * 0.015,
            ),
            image: DecorationImage(
              fit: BoxFit.cover,
              image: MemoryImage(audioProvider.currentSong.coverArt),
            ),
          ),
        );
      },
    );
  }
}
