import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/mixin_collection.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/custom_text_scroll.dart';
import 'package:music_player_frontend/core/ui/components/tiling/list_tile.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/hover_widget/hover_container.dart';
import 'package:provider/provider.dart';

class CustomListTile extends AbstractCustomListTile {
  const CustomListTile({
    super.key,
    required super.entity,
    required super.onTap,
    required super.onLongPress,
    required super.isSelected,
    super.leadingAction,
    super.trailingAction,
  });

  @override
  Widget buildListTileContent(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    var normalSize = height * 0.02;
    var smallSize = height * 0.015;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: HoverContainer(
          hoverColor: Theme.of(context).hoverColor,
          padding: EdgeInsets.symmetric(
            horizontal: height * 0.02,
            vertical: height * 0.01,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.only(right: height * 0.01),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      offset: const Offset(1, 1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: ImageWidget(
                    path:
                        entity is Song
                            ? (entity as Song).path
                            : (entity as AbstractCollection).songs[0].path,
                    type: ImageWidgetType.song,
                    hoveredChild: leadingAction,
                    child:
                        isSelected
                            ? ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
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
                            : null,
                  ),
                ),
              ),
              SizedBox(
                width: width * 0.15,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    entity is Song
                        ? Consumer<AbstractAudioProvider>(
                          builder: (_, audioProvider, __) {
                            return CustomTextScroll(
                              text: entity.name,
                              style: TextStyle(
                                color:
                                    audioProvider.currentSong.path ==
                                            (entity as Song).path
                                        ? Colors.blue
                                        : Colors.white,
                                fontSize: normalSize,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    offset: const Offset(1, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                        : CustomTextScroll(
                          text: entity.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: normalSize,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                offset: const Offset(1, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                    if (entity is Song)
                      Consumer<AbstractAudioProvider>(
                        builder: (_, audioProvider, __) {
                          return CustomTextScroll(
                            text: (entity as Song).artist.target.toString(),
                            style: TextStyle(
                              color:
                                  audioProvider.currentSong.path ==
                                          (entity as Song).path
                                      ? Colors.blue
                                      : Colors.white,
                              fontSize: smallSize,
                              fontWeight: FontWeight.normal,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  offset: const Offset(1, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const Spacer(),
              if (entity is Song)
                Consumer<AbstractAudioProvider>(
                  builder: (_, audioProvider, __) {
                    return Text(
                      "${(entity as Song).duration ~/ 60}:${((entity as Song).duration % 60).toString().padLeft(2, '0')}",
                      style: TextStyle(
                        color:
                            audioProvider.currentSong.path ==
                                    (entity as Song).path
                                ? Colors.blue
                                : Colors.white,
                        fontSize: normalSize,
                        fontWeight: FontWeight.normal,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(1, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    );
                  },
                ),

              trailingAction!,
            ],
          ),
        ),
      ),
    );
  }
}
