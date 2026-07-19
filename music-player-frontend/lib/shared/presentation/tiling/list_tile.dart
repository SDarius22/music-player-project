import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/shared/presentation/widgets/entity_cover.dart';
import 'package:fluenticons/fluenticons.dart';
import 'package:hover_widget/hover_container.dart';
import 'package:text_scroll/custom_text_scroll.dart';
import 'package:provider/provider.dart';

class CustomListTile extends StatelessWidget {
  final BaseEntity? entity;

  // actions[0] = main action (hover overlay on thumbnail)
  // actions[1+] = dropdown items
  final List<Widget> actions;
  final void Function(int dropdownIndex)? onDropdownSelected;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final bool isSelected;
  final bool isLoading;

  const CustomListTile({
    super.key,
    required this.onTap,
    required this.onLongPress,
    required this.entity,
    required this.isSelected,
    this.actions = const [],
    this.onDropdownSelected,
    this.isLoading = false,
  });

  const CustomListTile._loading({super.key})
    : actions = const [],
      onDropdownSelected = null,
      onTap = null,
      onLongPress = null,
      isSelected = false,
      entity = null,
      isLoading = true;

  static Widget loading({Key? key}) => CustomListTile._loading(key: key);

  Widget get _hoverOverlay =>
      actions.isNotEmpty ? actions[0] : const SizedBox.shrink();

  Widget _buildDropdown(BuildContext context) {
    if (actions.length <= 1) return const SizedBox.shrink();
    return PopupMenuButton<void>(
      icon: const Icon(FluentIcons.moreVertical, color: Colors.white, size: 24),
      padding: EdgeInsets.zero,
      itemBuilder:
          (context) => [
            for (int i = 1; i < actions.length; i++)
              PopupMenuItem<void>(
                onTap:
                    onDropdownSelected != null
                        ? () => onDropdownSelected!(i - 1)
                        : null,
                child: actions[i],
              ),
          ],
    );
  }

  Widget _buildLoadingTile(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final placeholderColor = Colors.white.withValues(alpha: 0.16);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: height * 0.01),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: placeholderColor,
              borderRadius: BorderRadius.circular(height * 0.015),
            ),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          SizedBox(width: width * 0.01),
          SizedBox(
            width: width * 0.15,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, color: placeholderColor),
                SizedBox(height: height * 0.008),
                Container(
                  height: 12,
                  width: width * 0.1,
                  color: placeholderColor,
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(height: 14, width: 36, color: placeholderColor),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildLoadingTile(context);

    final entity = this.entity!;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return MouseRegion(
      cursor:
          (onTap != null || onLongPress != null)
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
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
                  borderRadius: BorderRadius.circular(height * 0.015),
                  child: EntityCover(
                    entity: entity,
                    hoveredChild: _hoverOverlay,
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
                                    audioProvider.currentSong == entity
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
                                entity.artist.target?.name ?? 'Unknown Artist',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall!.copyWith(
                              color:
                                  audioProvider.currentSong == entity
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
                    final song = entity;
                    return Text(
                      "${song.durationInSeconds ~/ 60}:${(song.durationInSeconds % 60).toString().padLeft(2, '0')}",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color:
                            audioProvider.currentSong == song
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
              if (actions.length > 1) _buildDropdown(context),
            ],
          ),
        ),
      ),
    );
  }
}
