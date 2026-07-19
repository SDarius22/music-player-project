import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/album_provider.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/selection_provider.dart';
import 'package:music_player_frontend/core/services/entity_song_order.dart';
import 'package:music_player_frontend/shared/presentation/tiling/paginated_component.dart';
import 'package:music_player_frontend/shared/presentation/tiling/tile_type.dart';
import 'package:music_player_frontend/features/library/presentation/screens/base/entity_screen.dart';
import 'package:music_player_frontend/features/library/presentation/screens/add_or_export_screen.dart';
import 'package:fluenticons/fluenticons.dart';
import 'package:glass_kit/glass_container.dart';
import 'package:provider/provider.dart';

import 'package:music_player_frontend/shared/presentation/navigation/route_builder.dart';

class AlbumScreen extends EntityScreen<AlbumProvider> {
  static Route<void> route({required Album album}) {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) =>
          AlbumScreen(entity: album, provider: context.read<AlbumProvider>()),
      settings: RouteSettings(name: "/album/${album.getHash()}"),
    );
  }

  const AlbumScreen({
    super.key,
    required super.entity,
    required super.provider,
  });

  @override
  PreferredSizeWidget buildAppBar(BuildContext context, BaseEntity entity) {
    final album = entity as Album;
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        height: kToolbarHeight,
        padding: EdgeInsets.symmetric(horizontal: width * 0.01),
        margin: EdgeInsets.symmetric(vertical: width * 0.005),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () {
                debugPrint("Back");
                Navigator.pop(context);
              },
              icon: Icon(FluentIcons.back, size: 20, color: Colors.white),
            ),
            Text(
              entity.getName(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),

            const Spacer(),
            IconButton(
              tooltip: "Add",
              padding: EdgeInsets.all(height * 0.005),
              onPressed: () {
                debugPrint("Add ${album.name}");
                var abstractAppStateProvider =
                    Provider.of<AbstractAppStateProvider>(
                      context,
                      listen: false,
                    );
                abstractAppStateProvider.innerNavigatorKey.currentState?.push(
                  AddOrExportScreen.route(songs: album.getSongs()),
                );
              },
              icon: Icon(FluentIcons.add, color: Colors.white, size: 24),
            ),
            IconButton(
              tooltip: "Play",
              padding: EdgeInsets.all(height * 0.005),
              onPressed: () async {
                debugPrint("Play ${album.name}");
                await _playAlbum(context, album);
              },
              icon: Icon(FluentIcons.play, color: Colors.white, size: 24),
            ),
            IconButton(
              tooltip: "Shuffle",
              onPressed: () async {
                debugPrint("Shuffle ${album.name}");
                await _shuffleAlbum(context, album);
              },
              padding: EdgeInsets.all(height * 0.005),
              icon: Icon(FluentIcons.shuffleOn, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playSong(BuildContext context, Album album, Song song) async {
    final audioProvider = context.read<AudioProvider>();
    final songs = await EntitySongOrder.load(album, provider);
    if (songs.isEmpty) return;
    final selected = songs.where((candidate) => candidate == song).firstOrNull;
    await audioProvider.setQueueAndPlay(songs, selected ?? song);
  }

  Future<void> _playAlbum(BuildContext context, Album album) async {
    final songs = await EntitySongOrder.load(album, provider);
    if (songs.isEmpty) return;
    if (!context.mounted) return;
    final audioProvider = context.read<AudioProvider>();
    await audioProvider.setQueueAndPlay(songs, songs.first);
  }

  Future<void> _shuffleAlbum(BuildContext context, Album album) async {
    final songs = await EntitySongOrder.load(album, provider);
    if (songs.isEmpty) return;
    if (!context.mounted) return;
    final audioProvider = context.read<AudioProvider>();
    await audioProvider.setShuffleAndWait(true);
    final shuffled = List<Song>.from(songs)..shuffle();
    await audioProvider.setQueueAndPlay(songs, shuffled.first);
  }

  @override
  Widget buildContentSection(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    final album = entity as Album;
    final selection = context.watch<SelectionProvider>();
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    var margin = EdgeInsets.symmetric(
      vertical: height * 0.01,
      horizontal: width * 0.02,
    );
    var borderRadius = BorderRadius.circular(height * 0.015);

    return GlassContainer(
      margin: margin,
      color: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      borderRadius: borderRadius,
      blur: 45.0,
      borderWidth: 0.0,
      elevation: 3.0,
      shadowColor: Colors.black.withValues(alpha: 0.20),
      child: PaginatedComponent(
        type: TileType.list,
        itemExtent: height * 0.1,
        fetchPage:
            (page, size) =>
                provider.getSongsPage(album.getHash(), page: page, size: size),
        onTap: (BaseEntity entity, List<dynamic> items) {
          if (selection.selectedEntities.isNotEmpty) {
            _toggleSelection(selection, entity);
            return Future<void>.value();
          }
          return _playSong(context, album, entity as Song);
        },
        onLongPress: (entity, items) => _toggleSelection(selection, entity),
        isSelected: selection.isSelected,
        reloadToken: album.getHash(),
      ),
    );
  }

  void _toggleSelection(SelectionProvider selection, BaseEntity entity) {
    selection.isSelected(entity)
        ? selection.deselectEntity(entity)
        : selection.selectEntity(entity);
  }
}
