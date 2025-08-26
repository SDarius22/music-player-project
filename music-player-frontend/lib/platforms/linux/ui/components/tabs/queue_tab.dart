import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/ui/components/tabs/queue_tab.dart';
import 'package:music_player_frontend/platforms/linux/providers/audio_provider.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/tiling/list_component.dart';
import 'package:provider/provider.dart';

class QueueTab extends AbstractQueueTab {
  final ScrollController itemScrollController;

  const QueueTab(this.itemScrollController, {super.key});

  @override
  Widget buildQueueContent(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    return FutureBuilder(
      future: Provider.of<AudioProvider>(context, listen: false).queueFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("Queue is empty"));
        }
        debugPrint("QueueTab: ${snapshot.data!.length} items loaded");
        return Scrollbar(
          controller: itemScrollController,
          thumbVisibility: true,
          child: CustomScrollView(
            controller: itemScrollController,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  right: width * 0.01,
                  left: width * 0.01,
                  top: height * 0.01,
                ),
                sliver: ListComponent(
                  items: snapshot.data ?? [],
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
      },
    );
  }
}
