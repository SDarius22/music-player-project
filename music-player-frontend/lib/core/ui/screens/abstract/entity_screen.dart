import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/responsive_entity_screen.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';

abstract class EntityScreen<T extends QueryableProvider>
    extends ResponsiveScreen<BaseEntity> {
  final BaseEntity entity;
  final T provider;

  const EntityScreen({super.key, required this.entity, required this.provider});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: buildAppBar(context, entity),
      body: FutureBuilder(
        future: loadEntityData(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error loading data: ${snapshot.error}"));
          } else {
            final resolvedEntity = snapshot.hasData ? snapshot.data! : entity;
            return buildResponsiveBody(context, resolvedEntity);
          }
        },
      ),
    );
  }

  @override
  Widget buildCompactBody(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    return Column(
      children: [
        buildDetailsSection(context, entity, constraints),
        Expanded(child: buildContentSection(context, entity, constraints)),
      ],
    );
  }

  @override
  Widget buildExpandedBody(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: buildDetailsSection(context, entity, constraints)),
        Expanded(child: buildContentSection(context, entity, constraints)),
      ],
    );
  }

  Widget buildDetailsSection(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    final imageSize = constraints.maxWidth * 0.45;
    final infoSpacing = constraints.maxHeight * 0.005;
    final artworkBottomPadding = constraints.maxHeight * 0.01;
    final borderRadius = BorderRadius.circular(constraints.maxHeight * 0.015);

    return Column(
      children: [
        Hero(
          tag: entity.getHash(),
          child: Container(
            height: imageSize,
            width: imageSize,
            padding: EdgeInsets.only(bottom: artworkBottomPadding),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: ImageWidget(entity: entity),
            ),
          ),
        ),
        Text(
          entity.getName(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: infoSpacing),
        Text(
          entity.getSecondaryText(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget buildContentSection(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  );

  Widget _buildSongDetails(
    BuildContext context,
    Song song,
    double width,
    double height,
  ) {
    var song = entity as Song;
    return GlassContainer(
      color: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      borderRadius: BorderRadius.circular(
        MediaQuery.of(context).size.height * 0.015,
      ),
      blur: 45.0,
      borderWidth: 0.0,
      elevation: 3.0,
      shadowColor: Colors.black.withValues(alpha: 0.20),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.symmetric(
              vertical: height * 0.01,
              horizontal: width * 0.03,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  "Track Details",
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: height * 0.01),
                Text(
                  "Song Name:",
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  song.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                ),
                SizedBox(height: height * 0.01),
                Text(
                  "Artist:",
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  song.artist.target?.name ?? "Unknown Artist",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                ),
                SizedBox(height: height * 0.01),
                Text(
                  "Album:",
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  song.album.target?.name ?? "Unknown Album",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                ),
                SizedBox(height: height * 0.01),
                Text(
                  "Duration:",
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  Duration(seconds: song.durationInSeconds).pretty(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                ),
                SizedBox(height: height * 0.01),
                Text(
                  "Year:",
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  song.year > 0 ? song.year.toString() : "Unknown year",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                ),
                SizedBox(height: height * 0.01),
                Text(
                  "Extra Info:",
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Track: ${song.trackNumber} / Disc: ${song.discNumber}",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                ),
                Text(
                  "Play Count: ${song.playCount}",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                ),
                Text(
                  "Last Played: ${song.lastPlayed != null ? song.lastPlayed!.toLocal().toString() : "Never"}",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context, BaseEntity entity) {
    return const PreferredSize(
      preferredSize: Size.fromHeight(0),
      child: SizedBox.shrink(),
    );
  }

  Future<BaseEntity> loadEntityData(BuildContext context) async {
    try {
      final detailedEntity = await provider.fetchEntity(entity);
      return detailedEntity ?? entity;
    } catch (e) {
      debugPrint("Error fetching entity details: $e");
      return entity;
    }
  }
}
