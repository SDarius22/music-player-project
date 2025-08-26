import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract__named_entity.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_tile.dart';

abstract class AbstractGridComponent extends StatelessWidget {
  final List items;
  final Function(NamedEntity) onTap;
  final Function(NamedEntity) onLongPress;
  final bool Function(NamedEntity) isSelected;
  final Widget Function(NamedEntity)? buildLeftAction;
  final Widget Function(NamedEntity)? buildMainAction;
  final Widget Function(NamedEntity)? buildRightAction;
  final Widget Function()? buildExtraTile;

  const AbstractGridComponent({
    super.key,
    required this.items,
    required this.onTap,
    required this.onLongPress,
    required this.isSelected,
    this.buildLeftAction,
    this.buildMainAction,
    this.buildRightAction,
    this.buildExtraTile,
  });

  SliverGridDelegate getGridDelegate(BuildContext context);

  AbstractCustomGridTile getCustomGridTile(NamedEntity entity);

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: getGridDelegate(context),
      itemCount: items.length + (buildExtraTile != null ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (buildExtraTile != null && index == 0) {
          return buildExtraTile!();
        }
        return getCustomGridTile(
          items[index - (buildExtraTile != null ? 1 : 0)],
        );
      },
    );
  }
}
