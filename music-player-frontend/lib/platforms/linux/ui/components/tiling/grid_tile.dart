import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract__named_entity.dart';
import 'package:music_player_frontend/core/entities/abstract/mixin_collection.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/ui/components/custom_text_scroll.dart';
import 'package:music_player_frontend/core/ui/components/font_scaler.dart';
import 'package:music_player_frontend/core/ui/components/image_widget.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_tile.dart';
import 'package:music_player_frontend/platforms/linux/providers/audio_provider.dart';
import 'package:music_player_frontend/utils/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class CustomGridTile extends AbstractCustomGridTile {
  const CustomGridTile({
    super.key,
    required super.onTap,
    required super.onLongPress,
    required super.entity,
    required super.isSelected,
    super.leftAction = const SizedBox.shrink(),
    super.mainAction = const SizedBox.shrink(),
    super.rightAction = const SizedBox.shrink(),
  });

  String _pathForImageWidget(NamedEntity entity) {
    if (entity is Song) {
      return (entity).path;
    }
    if (entity is Playlist) {
      if (entity.name == 'Current Queue' && entity.indestructible) {
        return 'assets/current_queue.png';
      }
      if (entity.name == 'Create New Playlist' && entity.indestructible) {
        return 'assets/create_playlist.png';
      }
      if (entity.coverArt != null && entity.coverArt!.isNotEmpty) {
        return base64Encode(entity.coverArt!);
      }
      return (entity).pathsInOrder.isNotEmpty
          ? (entity).pathsInOrder.first
          : '';
    }
    if (entity is AbstractCollection) {
      return (entity as AbstractCollection).songs.isNotEmpty
          ? (entity as AbstractCollection).songs.first.path
          : '';
    }
    return '';
  }

  ImageWidgetType _getImageWidgetType(NamedEntity entity) {
    if (entity is Playlist) {
      if (entity.name == 'Current Queue' && entity.indestructible) {
        return ImageWidgetType.asset;
      }
      if (entity.name == 'Create New Playlist' && entity.indestructible) {
        return ImageWidgetType.asset;
      }
      if (entity.coverArt != null && entity.coverArt!.isNotEmpty) {
        return ImageWidgetType.bytes;
      }
    }
    return ImageWidgetType.song;
  }

  @override
  Widget buildGridTileContent(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Hero(
          tag: entity is Song ? (entity as Song).path : entity.name,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(width * 0.01),
            child: ImageWidget(
              path: _pathForImageWidget(entity),
              type: _getImageWidgetType(entity),
              hoveredChild: Row(
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
                        padding: EdgeInsets.only(bottom: height * 0.005),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: FractionalOffset.center,
                            end: FractionalOffset.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.0),
                              Colors.black.withValues(alpha: 0.5),
                              Colors.black,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                        child:
                            entity is Song
                                ? Consumer<AudioProvider>(
                                  builder: (_, audioProvider, __) {
                                    return CustomTextScroll(
                                      text: entity.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge!.copyWith(
                                        color:
                                            audioProvider.currentSong.path ==
                                                    (entity as Song).path
                                                ? Colors.blue
                                                : Colors.white,
                                        fontSize: FontScaler.scale(context, 20),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                )
                                : CustomTextScroll(text: entity.name),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
