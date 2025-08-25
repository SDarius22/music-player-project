import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_entity.dart';

abstract class AbstractListComponent extends StatelessWidget {
  final List<AbstractEntity> items;
  final double itemExtent;
  final Function(AbstractEntity) onTap;
  final Function(AbstractEntity) onLongPress;
  final bool Function(AbstractEntity) isSelected;
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

  Widget _getCustomListTile(AbstractEntity entity);

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