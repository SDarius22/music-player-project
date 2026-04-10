import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/triangle_clipper.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/local_libs/text_scroll/custom_text_scroll.dart';
import 'package:provider/provider.dart';

class CustomGridTile extends StatelessWidget {
  final Widget leftAction;
  final Widget mainAction;
  final Widget rightAction;
  final GestureTapCallback onTap;
  final GestureTapCallback onLongPress;
  final bool isSelected;
  final bool wide;
  final BaseEntity entity;

  const CustomGridTile({
    super.key,
    required this.onTap,
    required this.onLongPress,
    required this.entity,
    required this.isSelected,
    this.wide = false,
    this.leftAction = const SizedBox.shrink(),
    this.mainAction = const SizedBox.shrink(),
    this.rightAction = const SizedBox.shrink(),
  });

  Widget _buildTileContainer(
    BuildContext context,
    double height,
    double width,
  ) {
    if (wide) {
      return GlassContainer(
        blur: 20,
        borderRadius: BorderRadius.circular(height * 0.015),
        color: Colors.black.withValues(alpha: 0.5),
        borderColor: Colors.white.withValues(alpha: 0.2),
        child: Row(
          children: [
            _buildImageTile(context),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: height * 0.01),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.getName(),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium!.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entity.getSecondaryText(),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _buildImageTile(context);
  }

  Widget _buildImageTile(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final height = size.height;
    final width = size.width;
    return ImageWidget(
      entity: entity,
      hoveredChild: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            alignment: Alignment.topCenter,
            padding: EdgeInsets.only(left: height * 0.01, right: height * 0.01),
            child:
                wide
                    ? null
                    : CustomTextScroll(
                      text: entity.getSecondaryText(),
                      style: Theme.of(context).textTheme.titleSmall!,
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
              Expanded(child: FittedBox(fit: BoxFit.fill, child: mainAction)),
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
                wide
                    ? null
                    : entity is Song
                    ? Selector<AudioProvider, Song?>(
                      selector: (_, audioProvider) => audioProvider.currentSong,
                      builder: (_, song, _) {
                        return CustomTextScroll(
                          text: entity.getName(),
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall!.copyWith(
                            color:
                                song == (entity as Song)
                                    ? Colors.blue
                                    : Colors.white,
                          ),
                        );
                      },
                    )
                    : CustomTextScroll(
                      text: entity.getName(),
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall!.copyWith(color: Colors.white),
                    ),
          ),
        ],
      ),
      otherStackChildren: [
        if (!kIsWeb && entity.isLocal())
          Align(
            alignment: Alignment.topRight,
            child: ClipPath(
              clipper: TriangleClipper(),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.topRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 1.0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                padding: const EdgeInsets.only(top: 3.0, right: 3.0),
                alignment: Alignment.topRight,
                child: Icon(
                  Icons.file_download_done_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
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
                      size: 48,
                    ),
                  ),
                ),
              )
              : wide
              ? null
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
                        ? Selector<AudioProvider, Song?>(
                          selector:
                              (_, audioProvider) => audioProvider.currentSong,
                          builder: (_, song, _) {
                            return Text(
                              entity.getName(),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(
                                context,
                              ).textTheme.titleSmall!.copyWith(
                                color:
                                    song == (entity as Song)
                                        ? Colors.blue
                                        : Colors.white,
                              ),
                            );
                          },
                        )
                        : Text(
                          entity.getName(),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall!.copyWith(color: Colors.white),
                        ),
              ),
    );
  }

  Widget buildGridTileContent(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final height = size.height;
    final width = size.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        final needsWideFallbackWidth = wide && !constraints.hasBoundedWidth;
        final child = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(height * 0.015),
              clipBehavior: Clip.antiAlias,
              child: Hero(
                tag: entity.getHash(),
                child: _buildTileContainer(context, height, width),
              ),
            ),
          ),
        );

        if (needsWideFallbackWidth) {
          return SizedBox(width: width * 0.28, child: child);
        }
        return child;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildGridTileContent(context);
  }
}
