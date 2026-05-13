import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/artist_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/paginated_component.dart';
import 'package:music_player_frontend/core/ui/components/tiling/tile_type.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/entity_screen.dart';
import 'package:music_player_frontend/core/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:provider/provider.dart';

import 'abstract/route_builder.dart';

class ArtistScreen extends EntityScreen<ArtistProvider> {
  static Route<void> route({required Artist artist}) {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => ArtistScreen(
        entity: artist,
        provider: context.read<ArtistProvider>(),
      ),
      settings: RouteSettings(name: "/artist/${artist.id}"),
    );
  }

  const ArtistScreen({
    super.key,
    required super.entity,
    required super.provider,
  });

  @override
  PreferredSizeWidget buildAppBar(BuildContext context, BaseEntity entity) {
    final artist = entity as Artist;
    var height = MediaQuery.of(context).size.height;
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
                debugPrint("Add ${artist.name}");
                var abstractAppStateProvider =
                    Provider.of<AbstractAppStateProvider>(
                      context,
                      listen: false,
                    );
                abstractAppStateProvider.innerNavigatorKey.currentState?.push(
                  AddOrExportScreen.route(songs: artist.getSongs()),
                );
              },
              icon: Icon(FluentIcons.add, color: Colors.white, size: 24),
            ),
            IconButton(
              tooltip: "Play",
              padding: EdgeInsets.all(height * 0.005),
              onPressed: () async {
                debugPrint("Play ${artist.name}");
                var audioProvider = Provider.of<AudioProvider>(
                  context,
                  listen: false,
                );
                await audioProvider.setQueueAndPlay(
                  artist.getSongs(),
                  artist.getSongs().first,
                );
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

  Future<void> _playSong(BuildContext context, Artist artist, Song song) async {
    final audioProvider = context.read<AudioProvider>();
    await audioProvider.setQueueAndPlay(artist.getSongs(), song);
  }

  @override
  Widget buildContentSection(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    final artist = entity as Artist;
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
        fetchPage: (page, size) {
          return provider.getSongsPage(
            artist.getHash(),
            page: page,
            size: size,
          );
        },
        onTap:
            (BaseEntity entity, List<dynamic> items) =>
                _playSong(context, artist, entity as Song),
        onLongPress: (BaseEntity entity, List<dynamic> items) {},
        isSelected: (BaseEntity p1) {
          return false;
        },
        reloadToken: artist.getHash(),
      ),
    );
  }
}
