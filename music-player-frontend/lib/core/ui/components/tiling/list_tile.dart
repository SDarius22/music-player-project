import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/hover_widget/hover_container.dart';
import 'package:music_player_frontend/local_libs/text_scroll/custom_text_scroll.dart';
import 'package:provider/provider.dart';

class CustomListTile extends StatelessWidget {
  final BaseEntity entity;
  final Widget? leadingAction;
  final Widget? trailingAction;
  final GestureTapCallback onTap;
  final GestureLongPressCallback onLongPress;
  final bool isSelected;

  const CustomListTile({
    super.key,
    required this.entity,
    required this.onTap,
    required this.onLongPress,
    required this.isSelected,
    this.leadingAction = const SizedBox.shrink(),
    this.trailingAction = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    return _buildListTileContent(context);
  }

  Widget _buildListTileContent(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: HoverContainer(
          hoverColor: Theme.of(context).hoverColor,
          padding: EdgeInsets.symmetric(vertical: height * 0.01),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.only(right: width * 0.005),
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
                  borderRadius: BorderRadius.circular(
                    MediaQuery.of(context).size.height * 0.015,
                  ),
                  child: ImageWidget(
                    entity: entity,
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
                                    size: 48,
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
                        ? Consumer<AudioProvider>(
                          builder: (_, audioProvider, _) {
                            return CustomTextScroll(
                              text: entity.getName(),
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium!.copyWith(
                                color:
                                    audioProvider.currentSong ==
                                            (entity as Song)
                                        ? Colors.blue
                                        : Colors.white,
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
                          text: entity.getName(),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(
                            color: Colors.white,
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
                      Consumer<AudioProvider>(
                        builder: (_, audioProvider, _) {
                          return CustomTextScroll(
                            text:
                                (entity as Song).artist.target?.name ??
                                'Unknown Artist',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall!.copyWith(
                              color:
                                  audioProvider.currentSong == (entity as Song)
                                      ? Colors.blue
                                      : Colors.white,
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
                Consumer<AudioProvider>(
                  builder: (_, audioProvider, _) {
                    return Text(
                      "${(entity as Song).durationInSeconds ~/ 60}:${((entity as Song).durationInSeconds % 60).toString().padLeft(2, '0')}",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color:
                            audioProvider.currentSong == (entity as Song)
                                ? Colors.blue
                                : Colors.white,
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
