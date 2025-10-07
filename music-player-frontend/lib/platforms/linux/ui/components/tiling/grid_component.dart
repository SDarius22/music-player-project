import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_component.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_tile.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/tiling/grid_tile.dart';

class GridComponent extends AbstractGridComponent {
  const GridComponent({
    super.key,
    required super.items,
    required super.onTap,
    required super.onLongPress,
    required super.isSelected,
    super.buildLeftAction,
    super.buildMainAction,
    super.buildRightAction,
    super.buildExtraTile,
  });

  @override
  SliverGridDelegate getGridDelegate(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: width * 0.1,
      crossAxisSpacing: width * 0.0075,
      mainAxisSpacing: width * 0.0075,
    );
  }

  @override
  AbstractCustomGridTile getCustomGridTile(BaseEntity entity) {
    return CustomGridTile(
      onTap: () {
        onTap(entity);
      },
      onLongPress: () {
        onLongPress(entity);
      },
      entity: entity,
      isSelected: isSelected(entity),
      leftAction:
          buildLeftAction != null
              ? buildLeftAction!(entity)
              : const SizedBox.shrink(),
      rightAction:
          buildRightAction != null
              ? buildRightAction!(entity)
              : const SizedBox.shrink(),
      mainAction:
          buildMainAction != null
              ? buildMainAction!(entity)
              : const SizedBox.shrink(),
    );
  }
}
