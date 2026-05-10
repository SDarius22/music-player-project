import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/albums_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/custom_tile_component.dart';
import 'package:music_player_frontend/core/ui/components/tiling/paginated_component.dart';
import 'package:music_player_frontend/core/ui/components/tiling/tile_type.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/entity_screen.dart';
import 'package:music_player_frontend/core/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:provider/provider.dart';

import 'abstract/route_builder.dart';

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
              onPressed: () async {},
              padding: EdgeInsets.all(height * 0.005),
              icon: Icon(FluentIcons.shuffleOn, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildCompactBody(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    final album = entity as Album;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final imageSize = constraints.maxWidth * 0.45;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.05,
            vertical: height * 0.02,
          ),
          child: _buildAlbumHeader(
            context,
            album,
            imageSize: imageSize,
            borderRadius: BorderRadius.circular(12),
            infoSpacing: 4,
            artworkBottomPadding: 8,
          ),
        ),
        Expanded(
          child: _buildSongsPanel(
            context,
            album,
            margin: EdgeInsets.only(
              left: width * 0.05,
              right: width * 0.05,
              bottom: height * 0.025,
            ),
            borderRadius: BorderRadius.circular(12),
            itemExtent: height * 0.1,
            listPadding: EdgeInsets.symmetric(
              vertical: height * 0.01,
              horizontal: width * 0.01,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildExpandedBody(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    final album = entity as Album;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final borderRadius = BorderRadius.circular(height * 0.015);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAlbumHeader(
                  context,
                  album,
                  imageSize: height * 0.5,
                  borderRadius: borderRadius,
                  infoSpacing: height * 0.005,
                  artworkBottomPadding: height * 0.01,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _buildSongsPanel(
            context,
            album,
            margin: EdgeInsets.only(
              top: height * 0.025,
              bottom: height * 0.025,
              right: width * 0.05,
            ),
            borderRadius: borderRadius,
            itemExtent: height * 0.1,
            listPadding: EdgeInsets.symmetric(
              vertical: height * 0.01,
              horizontal: width * 0.01,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumHeader(
    BuildContext context,
    Album album, {
    required double imageSize,
    required BorderRadius borderRadius,
    required double infoSpacing,
    required double artworkBottomPadding,
  }) {
    return Column(
      children: [
        Hero(
          tag: album.getHash(),
          child: Container(
            height: imageSize,
            width: imageSize,
            padding: EdgeInsets.only(bottom: artworkBottomPadding),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: ImageWidget(entity: album),
            ),
          ),
        ),
        Text(
          album.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: infoSpacing),
        Text(
          album.getArtistName(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        SizedBox(height: infoSpacing),
        Text(
          "${album.getSongs().length} Songs | ${Duration(seconds: album.getDurationInSeconds()).pretty()}",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildSongsPanel(
    BuildContext context,
    Album album, {
    required EdgeInsets margin,
    required BorderRadius borderRadius,
    required double itemExtent,
    required EdgeInsets listPadding,
  }) {
    return GlassContainer(
      margin: margin,
      color: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      borderRadius: borderRadius,
      blur: 45.0,
      borderWidth: 0.0,
      elevation: 3.0,
      shadowColor: Colors.black.withValues(alpha: 0.20),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: listPadding,
            sliver: CustomTileComponent(
              tileType: TileType.list,
              items: album.getSongs(),
              itemExtent: itemExtent,
              isSelected: (entity) => false,
              onTap: (entity) async {
                await _playSong(context, album, entity as Song);
              },
              onLongPress: (entity) {},
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playSong(BuildContext context, Album album, Song song) async {
    final audioProvider = context.read<AudioProvider>();
    await audioProvider.setQueueAndPlay(album.getSongs(), song);
  }

  Future<void> _playAlbum(BuildContext context, Album album) async {
    if (album.getSongs().isEmpty) {
      return;
    }
    await _playSong(context, album, album.getSongs().first);
  }

  @override
  Widget buildContentSection(BuildContext context, BaseEntity entity, BoxConstraints constraints) {
    return GlassContainer(
      margin: margin,
      color: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      borderRadius: borderRadius,
      blur: 45.0,
      borderWidth: 0.0,
      elevation: 3.0,
      shadowColor: Colors.black.withValues(alpha: 0.20),
      child: PaginatedComponent(type: , fetchPage: fetchPage, onTap: onTap, onLongPress: onLongPress, isSelected: isSelected, reloadToken: reloadToken)
    );
  }
}
