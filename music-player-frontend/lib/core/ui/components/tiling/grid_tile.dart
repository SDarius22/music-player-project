import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract__named_entity.dart';

abstract class AbstractCustomGridTile extends StatelessWidget {
  final Widget leftAction;
  final Widget mainAction;
  final Widget rightAction;
  final GestureTapCallback onTap;
  final GestureTapCallback onLongPress;
  final bool isSelected;
  final NamedEntity entity;

  const AbstractCustomGridTile({
    super.key,
    required this.onTap,
    required this.onLongPress,
    required this.entity,
    required this.isSelected,
    this.leftAction = const SizedBox.shrink(),
    this.mainAction = const SizedBox.shrink(),
    this.rightAction = const SizedBox.shrink(),
  });

  Widget buildGridTileContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return buildGridTileContent(context);
  }
}
