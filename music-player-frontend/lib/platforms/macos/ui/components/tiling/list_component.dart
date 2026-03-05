import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/ui/components/tiling/list_component.dart';
import 'package:music_player_frontend/platforms/macos/ui/components/tiling/list_tile.dart';

class MacosListComponent extends AbstractListComponent {
  const MacosListComponent({
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
    return MacosCustomListTile(
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
