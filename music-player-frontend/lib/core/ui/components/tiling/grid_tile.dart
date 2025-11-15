import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/text_scroll/custom_text_scroll.dart';
import 'package:provider/provider.dart';

class CustomGridTile extends StatelessWidget {
  final Widget leftAction;
  final Widget mainAction;
  final Widget rightAction;
  final GestureTapCallback onTap;
  final GestureTapCallback onLongPress;
  final bool isSelected;
  final BaseEntity entity;

  const CustomGridTile({
    super.key,
    required this.onTap,
    required this.onLongPress,
    required this.entity,
    required this.isSelected,
    this.leftAction = const SizedBox.shrink(),
    this.mainAction = const SizedBox.shrink(),
    this.rightAction = const SizedBox.shrink(),
  });

  String _getEntityText(BaseEntity entity) {
    if (entity is Song) {
      return (entity).artist.target?.name ?? 'Unknown Artist';
    } else if (entity is Album) {
      return (entity).artist.target?.name ?? 'Unknown Artist';
    } else if (entity is Artist) {
      return "${entity.songs.length} Songs";
    } else if (entity is Playlist) {
      return "${entity.playlistSongs.length} Songs";
    }
    return "";
  }

  Widget buildGridTileContent(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final height = size.height;
    final width = size.width;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Hero(
          tag: entity is Song ? (entity as Song).path : entity.name,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height * 0.015),
            child: ImageWidget(
              entity: entity,
              hoveredChild: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    alignment: Alignment.topCenter,
                    padding: EdgeInsets.only(
                      left: height * 0.01,
                      right: height * 0.01,
                    ),
                    child: CustomTextScroll(
                      text: _getEntityText(entity),
                      style:
                          MusicPlayerTheme.getTheme(
                            context,
                            context.read<Scaler>(),
                          ).textTheme.titleSmall!,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: width * 0.035,
                        height: width * 0.035,
                        child: leftAction,
                      ),
                      Expanded(
                        child: FittedBox(fit: BoxFit.fill, child: mainAction),
                      ),
                      SizedBox(
                        width: width * 0.035,
                        height: width * 0.035,
                        child: rightAction,
                      ),
                    ],
                  ),
                  Container(
                    alignment: Alignment.bottomCenter,
                    padding: EdgeInsets.only(
                      left: height * 0.005,
                      right: height * 0.005,
                    ),
                    child:
                        entity is Song
                            ? Selector<AbstractAudioProvider, Song>(
                              selector:
                                  (_, audioProvider) =>
                                      audioProvider.currentSong,
                              builder: (_, song, __) {
                                return CustomTextScroll(
                                  text: entity.name,
                                  style: MusicPlayerTheme.getTheme(
                                    context,
                                    context.read<Scaler>(),
                                  ).textTheme.titleSmall!.copyWith(
                                    color:
                                        song.path == (entity as Song).path
                                            ? Colors.blue
                                            : Colors.white,
                                  ),
                                );
                              },
                            )
                            : CustomTextScroll(
                              text: entity.name,
                              style: MusicPlayerTheme.getTheme(
                                context,
                                context.read<Scaler>(),
                              ).textTheme.titleSmall!.copyWith(
                                color: Colors.white,
                              ),
                            ),
                  ),
                ],
              ),
              child:
                  isSelected
                      ? ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.4),
                            alignment: Alignment.center,
                            child: Icon(
                              FluentIcons.check,
                              color: Colors.white,
                              size: height * 0.05,
                            ),
                          ),
                        ),
                      )
                      : Container(
                        alignment: Alignment.bottomCenter,
                        padding: EdgeInsets.only(
                          left: height * 0.01,
                          right: height * 0.01,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: const FractionalOffset(0.5, 3 / 4),
                            end: FractionalOffset.bottomCenter,
                            colors: [
                              Colors.black26.withValues(alpha: 0.0),
                              Colors.black26.withValues(alpha: 0.5),
                              Colors.black26.withValues(alpha: 0.75),
                            ],
                            stops: const [0.0, 0.5, 0.7],
                          ),
                        ),
                        child:
                            entity is Song
                                ? Selector<AbstractAudioProvider, Song>(
                                  selector:
                                      (_, audioProvider) =>
                                          audioProvider.currentSong,
                                  builder: (_, song, __) {
                                    return Text(
                                      entity.name,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: MusicPlayerTheme.getTheme(
                                        context,
                                        context.read<Scaler>(),
                                      ).textTheme.titleSmall!.copyWith(
                                        color:
                                            song.path == (entity as Song).path
                                                ? Colors.blue
                                                : Colors.white,
                                      ),
                                    );
                                  },
                                )
                                : Text(
                                  entity.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: MusicPlayerTheme.getTheme(
                                    context,
                                    context.read<Scaler>(),
                                  ).textTheme.titleSmall!.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                      ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildGridTileContent(context);
  }
}
