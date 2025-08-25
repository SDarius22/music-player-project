import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_entity.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_tile.dart';

abstract class AbstractGridComponent extends StatelessWidget {
  final List items;
  final Function(AbstractEntity) onTap;
  final Function(AbstractEntity) onLongPress;
  final bool Function(AbstractEntity) isSelected;
  final Widget Function(AbstractEntity)? buildLeftAction;
  final Widget Function(AbstractEntity)? buildMainAction;
  final Widget Function(AbstractEntity)? buildRightAction;
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

  SliverGridDelegate _getGridDelegate();
  AbstractCustomGridTile _getCustomGridTile(AbstractEntity entity);

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: _getGridDelegate(),
      itemCount: items.length + (buildExtraTile != null ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (buildExtraTile != null && index == 0) {
          return buildExtraTile!();
        }
        return _getCustomGridTile(items[index - (buildExtraTile != null ? 1 : 0)]);
      },
    );
  }


}