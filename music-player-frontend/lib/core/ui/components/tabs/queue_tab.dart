import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/custom_tile_component.dart';
import 'package:music_player_frontend/core/ui/components/tiling/tile_type.dart';
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
    final audioProvider = Provider.of<AudioProvider>(context);

    return Scrollbar(
      controller: itemScrollController,
      thumbVisibility: true,
      child: CustomScrollView(
        controller: itemScrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(right: width * 0.01),
            sliver: CustomTileComponent(
              tileType: TileType.list,
              items: audioProvider.normalQueue,
              actions: [
                (_) => const SizedBox.shrink(),
                (_) => const SizedBox.shrink(),
                (_) => const Text('Remove from queue'),
              ],
              onDropdownSelected: (entity, dropdownIndex) async {
                if (dropdownIndex == 0 && entity is Song) {
                  await Provider.of<AudioProvider>(
                    context,
                    listen: false,
                  ).removeFromQueue(entity);
                }
              },
              itemExtent: height * 0.085,
              isSelected: (entity) {
                return entity == audioProvider.currentSong;
              },
              onTap: (entity) async {
                debugPrint("Tapped on: ${entity.getName()}");
                var audioProvider = Provider.of<AudioProvider>(
                  context,
                  listen: false,
                );
                await audioProvider.setCurrentSongAndPlay(entity as Song);
              },
              onLongPress: (entity) {
                debugPrint("Long pressed on: ${entity.getName()}");
              },
              enrichEntity: (entity) async {
                if (entity is Song) {
                  var song = await Provider.of<SongProvider>(
                    context,
                    listen: false,
                  ).enrichSong(entity);
                  return song;
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
