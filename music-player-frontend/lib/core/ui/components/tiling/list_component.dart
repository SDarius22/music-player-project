import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';

abstract class AbstractListComponent extends StatelessWidget {
  final List<BaseEntity> items;
  final double itemExtent;
  final Function(BaseEntity) onTap;
  final Function(BaseEntity) onLongPress;
  final bool Function(BaseEntity) isSelected;
  final Widget? leadingAction;
  final Widget? trailingAction;

  const AbstractListComponent({
    super.key,
    required this.items,
    required this.itemExtent,
    required this.onTap,
    required this.onLongPress,
    required this.isSelected,
    this.leadingAction,
    this.trailingAction,
  });

  Widget getCustomListTile(BaseEntity entity);

  @override
  Widget build(BuildContext context) {
    return SliverFixedExtentList.builder(
      itemCount: items.length,
      itemExtent: itemExtent,
      itemBuilder: (BuildContext context, int index) {
        return getCustomListTile(items[index]);
      },
    );
  }
}
