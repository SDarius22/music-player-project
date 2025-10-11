import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/custom_text_scroll.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_tile.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/platforms/android/ui/components/theme.dart';
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

  @override
  Widget buildGridTileContent(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final height = size.height;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Hero(
          tag: entity is Song ? (entity as Song).path : entity.name,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height * 0.01),
            child: ImageWidget(
              entity: entity,
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
                          bottom: height * 0.001,
                          left: height * 0.005,
                          right: height * 0.005,
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
                                    return CustomTextScroll(
                                      text: entity.name,
                                      style: MusicPlayerTheme.getTheme(
                                        context,
                                      ).textTheme.titleSmall!.copyWith(
                                        color:
                                            song.path == (entity as Song).path
                                                ? Colors.blue
                                                : Colors.white,
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
