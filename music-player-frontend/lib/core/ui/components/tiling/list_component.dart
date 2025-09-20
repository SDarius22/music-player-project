import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_named_entity.dart';

abstract class AbstractListComponent extends StatelessWidget {
  final List<NamedEntity> items;
  final double itemExtent;
  final Function(NamedEntity) onTap;
  final Function(NamedEntity) onLongPress;
  final bool Function(NamedEntity) isSelected;
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

  Widget getCustomListTile(NamedEntity entity);

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
