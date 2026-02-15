import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/tabs/queue_tab.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/tiling/list_component.dart';
import 'package:provider/provider.dart';

class QueueTab extends AbstractQueueTab {
  final ScrollController itemScrollController;

  const QueueTab({super.key, required this.itemScrollController});

  @override
  Widget buildQueueContent(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    return Scrollbar(
      controller: itemScrollController,
      thumbVisibility: true,
      child: CustomScrollView(
        controller: itemScrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(right: width * 0.01),
            sliver: LinuxListComponent(
              items: Provider.of<AudioProvider>(context).normalQueue,
              itemExtent: height * 0.1,
              isSelected: (entity) {
                return false;
              },
              onTap: (entity) async {
                debugPrint("Tapped on: ${entity.name}");
                var audioProvider = Provider.of<AudioProvider>(
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
