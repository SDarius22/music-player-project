import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/local_libs/text_scroll/custom_text_scroll.dart';
import 'package:provider/provider.dart';

class CustomGridTile extends StatelessWidget {
  final BaseEntity? entity;
  final bool isWide;
  // actions[0] = main action (center button)
  // actions[1] = secondary action (left button)
  // actions[2+] = dropdown items
  final List<Widget> actions;
  final void Function(int dropdownIndex)? onDropdownSelected;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final bool isSelected;
  final bool isExtraTile;
  final bool isLoading;

  const CustomGridTile({
    super.key,
    required this.onTap,
    required this.onLongPress,
    required this.entity,
    required this.isSelected,
    this.isWide = false,
    this.actions = const [],
    this.onDropdownSelected,
    this.isExtraTile = false,
    this.isLoading = false,
  });

  const CustomGridTile._loading({super.key, this.isWide = false})
    : actions = const [],
      onDropdownSelected = null,
      onTap = null,
      onLongPress = null,
      isSelected = false,
      isExtraTile = false,
      entity = null,
      isLoading = true;

  static Widget loading({Key? key, bool isWide = false}) =>
      CustomGridTile._loading(key: key, isWide: isWide);

  Widget get _mainAction =>
      actions.isNotEmpty ? actions[0] : const SizedBox.shrink();

  Widget get _secondaryAction =>
      actions.length > 1 ? actions[1] : const SizedBox.shrink();

  Widget _buildDropdown(BuildContext context) {
    if (actions.length <= 2) return const SizedBox.shrink();
    return PopupMenuButton<void>(
      icon: const Icon(FluentIcons.moreVertical, color: Colors.white, size: 24),
      padding: EdgeInsets.zero,
      itemBuilder:
          (context) => [
            for (int i = 2; i < actions.length; i++)
              PopupMenuItem<void>(
                onTap:
                    onDropdownSelected != null
                        ? () => onDropdownSelected!(i - 2)
                        : null,
                child: actions[i],
              ),
          ],
    );
  }

  Widget _buildLoadingTile(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final placeholderColor = Colors.white.withValues(alpha: 0.16);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height * 0.015),
      child: Container(
        color: placeholderColor,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildImageTile(BuildContext context) {
    final entity = this.entity!;
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
                isWide || isExtraTile
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
                child: _secondaryAction,
              ),
              Expanded(child: FittedBox(fit: BoxFit.fill, child: _mainAction)),
              SizedBox(
                width: width * 0.035,
                height: width * 0.035,
                child: _buildDropdown(context),
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
                isWide
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
                            color: song == entity ? Colors.blue : Colors.white,
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
        if (isSelected)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
                alignment: Alignment.center,
                child: Icon(FluentIcons.check, color: Colors.white, size: 48),
              ),
            ),
          ),
      ],
      child:
          isWide
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
                                    song == entity ? Colors.blue : Colors.white,
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

  Widget _buildTileContainer(
    BuildContext context,
    double height,
    double width,
  ) {
    final entity = this.entity!;
    if (isWide) {
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildLoadingTile(context);

    final entity = this.entity!;
    final size = MediaQuery.sizeOf(context);
    final height = size.height;
    final width = size.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        final needsFallbackWidth = isWide && !constraints.hasBoundedWidth;
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
        return needsFallbackWidth
            ? SizedBox(width: width * 0.28, child: child)
            : child;
      },
    );
  }
}
