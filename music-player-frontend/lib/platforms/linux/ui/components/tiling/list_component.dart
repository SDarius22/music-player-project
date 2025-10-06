import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/ui/components/tiling/list_component.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/tiling/list_tile.dart';

class ListComponent extends AbstractListComponent {
  const ListComponent({
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
    return CustomListTile(
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
