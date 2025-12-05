import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/providers/selection_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_component.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

abstract class MultipleEntitiesScreen<T extends QueryableProvider>
    extends StatelessWidget {
  final T provider;

  const MultipleEntitiesScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    return GlassScaffold(
      appBar: buildAppBar(context),
      body: Padding(
        padding: buildPadding(width, height),
        child: Selector<T, Future>(
          selector: (context, provider) => provider.query,
          builder: (context, query, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                buildHeader(context),
                Expanded(
                  child: FutureBuilder(
                    future: query,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        debugPrint(snapshot.error.toString());
                        debugPrintStack();
                        return const Center(
                          child: Text('Error when loading :('),
                        );
                      }
                      customLogic(snapshot);
                      return CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.only(
                              left: width * 0.01,
                              right: width * 0.01,
                            ),
                            sliver: buildGridComponent(context, snapshot),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void customLogic(AsyncSnapshot snapshot) {
    // Can be overridden by subclasses for custom logic after data is loaded
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    return const PreferredSize(
      preferredSize: Size.fromHeight(0),
      child: SizedBox.shrink(),
    );
  }

  EdgeInsetsGeometry buildPadding(double width, double height) {
    return EdgeInsets.zero;
  }

  Widget buildHeader(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget buildLeftAction(BaseEntity entity, BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget buildMainAction(BaseEntity entity, BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget buildRightAction(BaseEntity entity, BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget Function(BuildContext)? get buildExtraTile => null;

  Future<void> onEntityTap(
    BaseEntity entity,
    AsyncSnapshot snapshot,
    BuildContext context,
  ) async {
    // Can be overridden by subclasses for custom tap behavior
  }

  Widget buildGridComponent(BuildContext context, AsyncSnapshot snapshot) {
    final selectionProvider = Provider.of<SelectionProvider>(
      context,
      listen: false,
    );
    return Selector<SelectionProvider, Set<BaseEntity>>(
      selector:
          (context, selectionProvider) => selectionProvider.selectedEntities,
      builder: (context, selected, child) {
        return CustomGridComponent(
          items: snapshot.data ?? [],
          isSelected: (entity) {
            return selected.contains(entity);
          },
          onTap: (entity) async {
            if (selected.isNotEmpty) {
              if (selected.contains(entity)) {
                selectionProvider.deselectEntity(entity);
              } else {
                selectionProvider.selectEntity(entity);
              }
              return;
            }
            await onEntityTap(entity, snapshot, context);
          },
          onLongPress: (entity) {
            debugPrint("long pressed ${entity.name}");
            if (selected.contains(entity)) {
              selectionProvider.deselectEntity(entity);
            } else {
              selectionProvider.selectEntity(entity);
            }
          },
          buildLeftAction: (entity) {
            if (selected.contains(entity)) {
              return const SizedBox.shrink();
            }
            return buildLeftAction(entity, context);
          },
          buildMainAction: (entity) {
            if (selected.contains(entity)) {
              return const Icon(FluentIcons.checkCircleOn, color: Colors.white);
            }
            if (selected.isNotEmpty) {
              return const Icon(
                FluentIcons.checkCircleOff,
                color: Colors.white,
              );
            }
            return buildMainAction(entity, context);
          },
          buildRightAction: (entity) {
            if (selected.contains(entity)) {
              return const SizedBox.shrink();
            }
            return buildRightAction(entity, context);
          },
          buildExtraTile:
              buildExtraTile == null ? null : () => buildExtraTile!(context),
        );
      },
    );
  }
}
