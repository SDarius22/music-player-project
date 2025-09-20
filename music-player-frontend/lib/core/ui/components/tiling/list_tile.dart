import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_named_entity.dart';

abstract class AbstractCustomListTile extends StatelessWidget {
  final NamedEntity entity;
  final Widget? leadingAction;
  final Widget? trailingAction;
  final GestureTapCallback onTap;
  final GestureLongPressCallback onLongPress;
  final bool isSelected;

  const AbstractCustomListTile({
    super.key,
    required this.entity,
    required this.onTap,
    required this.onLongPress,
    required this.isSelected,
    this.leadingAction = const SizedBox.shrink(),
    this.trailingAction = const SizedBox.shrink(),
  });

  Widget buildListTileContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return buildListTileContent(context);
  }
}
