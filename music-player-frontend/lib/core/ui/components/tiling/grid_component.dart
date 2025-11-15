import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_tile.dart';

class CustomGridComponent extends StatelessWidget {
  final List items;
  final Function(BaseEntity) onTap;
  final Function(BaseEntity) onLongPress;
  final bool Function(BaseEntity) isSelected;
  final Widget Function(BaseEntity)? buildLeftAction;
  final Widget Function(BaseEntity)? buildMainAction;
  final Widget Function(BaseEntity)? buildRightAction;
  final Widget Function()? buildExtraTile;

  const CustomGridComponent({
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

  SliverGridDelegate getGridDelegate(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: height * 0.2,
      crossAxisSpacing: width * 0.005,
      mainAxisSpacing: width * 0.005,
    );
  }

  CustomGridTile getCustomGridTile(BaseEntity entity) {
    return CustomGridTile(
      entity: entity,
      isSelected: isSelected(entity),
      onTap: () => onTap(entity),
      onLongPress: () => onLongPress(entity),
      leftAction:
          buildLeftAction != null
              ? buildLeftAction!(entity)
              : const SizedBox.shrink(),
      mainAction:
          buildMainAction != null
              ? buildMainAction!(entity)
              : const SizedBox.shrink(),
      rightAction:
          buildRightAction != null
              ? buildRightAction!(entity)
              : const SizedBox.shrink(),
    );
  }

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
