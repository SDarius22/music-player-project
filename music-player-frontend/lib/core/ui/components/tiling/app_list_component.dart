import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/ui/components/tiling/app_list_tile.dart';
import 'package:music_player_frontend/core/ui/components/tiling/list_component.dart';

class AppListComponent extends AbstractListComponent {
  const AppListComponent({
    super.key,
    required super.items,
    required super.itemExtent,
    required super.onTap,
    required super.onLongPress,
    required super.isSelected,
    super.leadingAction,
    super.trailingAction,
  });

  @override
  Widget getCustomListTile(BaseEntity entity) {
    return AppCustomListTile(
      onTap: () {
        onTap(entity);
      },
      onLongPress: () {
        onLongPress(entity);
      },
      isSelected: isSelected(entity),
      entity: entity,
      leadingAction: leadingAction ?? const SizedBox.shrink(),
      trailingAction: trailingAction ?? const SizedBox.shrink(),
    );
  }
}