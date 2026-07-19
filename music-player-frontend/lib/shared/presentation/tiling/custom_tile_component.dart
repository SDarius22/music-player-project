import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/shared/presentation/tiling/grid_tile.dart';
import 'package:music_player_frontend/shared/presentation/tiling/list_tile.dart';
import 'package:music_player_frontend/shared/presentation/tiling/tile_type.dart';

class CustomTileComponent extends StatelessWidget {
  final TileType tileType;
  final List<dynamic> items;

  // actions[0] = main, actions[1] = secondary/left, actions[2+] = dropdown items
  final List<Widget Function(BaseEntity)> actions;

  // Fires when a dropdown item (actions[2+]) is tapped.
  // dropdownIndex is 0-based within the dropdown (0 = actions[2]).
  final void Function(BaseEntity entity, int dropdownIndex)? onDropdownSelected;
  final bool Function(BaseEntity entity, int dropdownIndex)?
  isDropdownActionVisible;
  final Function(BaseEntity) onTap;
  final Function(BaseEntity) onLongPress;
  final bool Function(BaseEntity) isSelected;
  final Function(BaseEntity)? enrichEntity;
  final bool showEnrichLoadingPlaceholder;
  final Widget Function()? buildExtraTile; // grid/wide only
  final double itemExtent; // list only

  const CustomTileComponent({
    super.key,
    required this.tileType,
    required this.items,
    required this.onTap,
    required this.onLongPress,
    required this.isSelected,
    this.actions = const [],
    this.onDropdownSelected,
    this.isDropdownActionVisible,
    this.enrichEntity,
    this.showEnrichLoadingPlaceholder = true,
    this.buildExtraTile,
    this.itemExtent = 72,
  });

  List<int> _visibleDropdownIndices(BaseEntity entity) => [
    for (var index = 2; index < actions.length; index++)
      if (isDropdownActionVisible?.call(entity, index - 2) ?? true) index - 2,
  ];

  List<Widget> _buildActions(BaseEntity entity) => [
    ...actions.take(2).map((action) => action(entity)),
    for (final index in _visibleDropdownIndices(entity))
      actions[index + 2](entity),
  ];

  Widget _buildTile(BaseEntity entity) {
    final builtActions = _buildActions(entity);
    final visibleDropdownIndices = _visibleDropdownIndices(entity);
    final void Function(int)? drop =
        onDropdownSelected != null
            ? (i) => onDropdownSelected!(entity, visibleDropdownIndices[i])
            : null;

    if (tileType == TileType.list) {
      return CustomListTile(
        entity: entity,
        isSelected: isSelected(entity),
        onTap: () => onTap(entity),
        onLongPress: () => onLongPress(entity),
        actions: builtActions,
        onDropdownSelected: drop,
      );
    }
    return CustomGridTile(
      isWide: tileType == TileType.wide,
      entity: entity,
      isSelected: isSelected(entity),
      onTap: () => onTap(entity),
      onLongPress: () => onLongPress(entity),
      actions: builtActions,
      onDropdownSelected: drop,
    );
  }

  Widget _buildTileWithEnrich(BaseEntity entity) => FutureBuilder(
    future: enrichEntity != null ? enrichEntity!(entity) : Future.value(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        if (!showEnrichLoadingPlaceholder) {
          return _buildTile(entity);
        }
        return tileType == TileType.list
            ? CustomListTile.loading()
            : CustomGridTile.loading(isWide: tileType == TileType.wide);
      }
      final enriched = snapshot.data;
      return _buildTile(enriched is BaseEntity ? enriched : entity);
    },
  );

  SliverGridDelegate _gridDelegate(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: size.height * 0.2,
      crossAxisSpacing: size.width * 0.005,
      mainAxisSpacing: size.width * 0.005,
    );
  }

  Widget _buildGrid(BuildContext context) {
    final extraCount = buildExtraTile != null ? 1 : 0;
    return SliverGrid.builder(
      gridDelegate: _gridDelegate(context),
      itemCount: items.length + extraCount,
      itemBuilder: (context, index) {
        if (buildExtraTile != null && index == 0) return buildExtraTile!();
        return _buildTileWithEnrich(items[index - extraCount]);
      },
    );
  }

  Widget _buildList() => SliverFixedExtentList.builder(
    itemCount: items.length,
    itemExtent: itemExtent,
    itemBuilder: (context, index) => _buildTileWithEnrich(items[index]),
  );

  @override
  Widget build(BuildContext context) => switch (tileType) {
    TileType.grid || TileType.wide => _buildGrid(context),
    TileType.list => _buildList(),
  };
}
