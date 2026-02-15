import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/tabs/details_tab.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';
import 'package:music_player_frontend/local_libs/text_scroll/custom_text_scroll.dart';
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
    return Consumer<AudioProvider>(
      builder: (_, audioProvider, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(
                    MediaQuery.of(context).size.height * 0.015,
                  ),
                  image: DecorationImage(
                    fit: BoxFit.fill,
                    image: MemoryImage(audioProvider.currentSong.coverArt),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            CustomTextScroll(
              text: audioProvider.currentSong.name,
              style:
                  MusicPlayerTheme.getTheme(
                    context,
                    context.read<Scaler>(),
                  ).textTheme.headlineMedium!,
            ),
            const SizedBox(height: 10),
            CustomTextScroll(
              text:
                  audioProvider.currentSong.artist.target?.name ??
                  "Unknown Artist",
              style:
                  MusicPlayerTheme.getTheme(
                    context,
                    context.read<Scaler>(),
                  ).textTheme.bodyLarge!,
            ),
          ],
        );
      },
    );
  }
}
