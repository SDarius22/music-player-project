import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/tabs/queue_tab.dart';
import 'package:music_player_frontend/platforms/android/ui/components/tiling/list_component.dart';
import 'package:provider/provider.dart';

class QueueTab extends AbstractQueueTab {
  final ScrollController itemScrollController;

  const QueueTab({super.key, required this.itemScrollController});

  @override
  Widget buildQueueContent(BuildContext context) {
    var height = MediaQuery.of(context).size.height;

    return Scrollbar(
      controller: itemScrollController,
      thumbVisibility: true,
      child: CustomScrollView(
        controller: itemScrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.zero,
            sliver: ListComponent(
              items:
                  Provider.of<AbstractAudioProvider>(
                    context,
                  ).audioService.queue,
              itemExtent: height * 0.075,
              isSelected: (entity) {
                return false;
              },
              onTap: (entity) async {
                debugPrint("Tapped on: ${entity.name}");
                var audioProvider = Provider.of<AbstractAudioProvider>(
                  context,
                  listen: false,
                );
                await audioProvider.setCurrentSong(entity as Song);
                audioProvider.play();
              },
              onLongPress: (entity) {
                debugPrint("Long pressed on: ${entity.name}");
                // audioProvider.showContextMenu(entity);
              },
            ),
          ),
        ],
      ),
    );
  }
}
