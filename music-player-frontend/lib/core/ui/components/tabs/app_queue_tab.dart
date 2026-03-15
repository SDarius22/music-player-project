import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/list_component.dart';
import 'package:provider/provider.dart';

class QueueTab extends StatelessWidget {
  final ScrollController itemScrollController;

  const QueueTab({super.key, required this.itemScrollController});

  @override
  Widget build(BuildContext context) {
    return _buildQueueContent(context);
  }

  Widget _buildQueueContent(BuildContext context) {
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
            sliver: ListComponent(
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
                await audioProvider.setCurrentSongAndPlay(entity as Song);
              },
              onLongPress: (entity) {
                debugPrint("Long pressed on: ${entity.name}");
              },
            ),
          ),
        ],
      ),
    );
  }
}
