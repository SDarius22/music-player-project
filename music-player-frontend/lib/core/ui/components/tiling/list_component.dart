import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/ui/components/tiling/list_tile.dart';

class ListComponent extends StatelessWidget {
  final List<BaseEntity> items;
  final double itemExtent;
  final Function(BaseEntity) onTap;
  final Function(BaseEntity) onLongPress;
  final bool Function(BaseEntity) isSelected;
  final Widget? leadingAction;
  final Widget? trailingAction;

  const ListComponent({
    super.key,
    required this.items,
    required this.itemExtent,
    required this.onTap,
    required this.onLongPress,
    required this.isSelected,
    this.leadingAction,
    this.trailingAction,
  });

  Widget _getCustomListTile(BaseEntity entity) {
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

  @override
  Widget build(BuildContext context) {
    return SliverFixedExtentList.builder(
      itemCount: items.length,
      itemExtent: itemExtent,
      itemBuilder: (BuildContext context, int index) {
        return _getCustomListTile(items[index]);
      },
    );
  }
}
