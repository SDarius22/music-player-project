import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/providers/selection_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/paginated_component.dart';
import 'package:music_player_frontend/core/ui/components/tiling/tile_type.dart';
import 'package:music_player_frontend/core/ui/components/widgets/search_header.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

abstract class MultipleEntitiesScreen<T extends QueryableProvider>
    extends StatefulWidget {
  final T provider;

  const MultipleEntitiesScreen({super.key, required this.provider});

  String get screenTitle;

  // actions[0]: main action (grid center button)
  Widget buildMainAction(BaseEntity entity, BuildContext context) =>
      const SizedBox.shrink();

  // actions[1]: secondary action (grid left button, list hover overlay)
  Widget buildLeftAction(BaseEntity entity, BuildContext context) =>
      const SizedBox.shrink();

  // actions[2+]: each entry provides the display widget for a dropdown item
  List<Widget Function(BaseEntity, BuildContext)> get extraActions => [];

  // Called when dropdown item at [dropdownIndex] is tapped.
  void onDropdownAction(
    BaseEntity entity,
    int dropdownIndex,
    BuildContext context,
  ) {}

  Widget Function(BuildContext)? get buildExtraTile => null;

  Future<void> onEntityTap(
    BaseEntity entity,
    List<dynamic> items,
    BuildContext context,
  ) async {}

  @override
  State<MultipleEntitiesScreen<T>> createState() =>
      _MultipleEntitiesScreenState<T>();
}

class _MultipleEntitiesScreenState<T extends QueryableProvider>
    extends State<MultipleEntitiesScreen<T>> {
  late String _sortField;
  late bool _localOnly;
  late bool _ascending;
  String _query = '';
  late final AbstractAppStateProvider _appStateProvider;
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    _localOnly = false;
    _sortField = widget.provider.sortFields.keys.firstOrNull ?? 'Name';
    _ascending = true;
    _appStateProvider = context.read<AbstractAppStateProvider>();
    (widget.provider as ChangeNotifier).addListener(_onProviderChanged);
    _appStateProvider.refreshRequestNotifier.addListener(_onGlobalRefresh);
    _appStateProvider.shouldDisplayLocalOnly.addListener(_onLocalOnlyChanged);
    _reloadToken++;
  }

  @override
  void dispose() {
    (widget.provider as ChangeNotifier).removeListener(_onProviderChanged);
    _appStateProvider.refreshRequestNotifier.removeListener(_onGlobalRefresh);
    _appStateProvider.shouldDisplayLocalOnly.removeListener(
      _onLocalOnlyChanged,
    );
    super.dispose();
  }

  void _onGlobalRefresh() {
    if (!mounted) return;
    _triggerReload();
  }

  void _onLocalOnlyChanged() {
    _localOnly = _appStateProvider.shouldDisplayLocalOnly.value;
    _triggerReload();
  }

  void _onProviderChanged() => _triggerReload();

  void _triggerReload() {
    if (!mounted) return;
    setState(() => _reloadToken++);
  }

  void _onToggleLocalOnly(bool value) {
    _localOnly = value;
    _triggerReload();
  }

  void _onQuery(String q) {
    _query = q;
    _triggerReload();
  }

  void _onSortField(String field) {
    _sortField = field;
    _triggerReload();
  }

  void _onAscending(bool asc) {
    _ascending = asc;
    _triggerReload();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return GlassScaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          height: kToolbarHeight,
          padding: EdgeInsets.symmetric(horizontal: width * 0.01),
          margin: EdgeInsets.symmetric(vertical: width * 0.005),
          child: SearchHeader(
            title: widget.screenTitle,
            sortFields: widget.provider.sortFields,
            initialSortField: _sortField,
            initialAscending: _ascending,
            initialLocalOnly: _localOnly,
            onLocalOnly: _onToggleLocalOnly,
            onQuery: _onQuery,
            onSortField: _onSortField,
            onAscending: _onAscending,
          ),
        ),
      ),
      body: _buildGrid(context),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final selectionProvider = Provider.of<SelectionProvider>(
      context,
      listen: false,
    );
    return Selector<SelectionProvider, Set<BaseEntity>>(
      selector: (context, p) => p.selectedEntities,
      builder: (context, selected, child) {
        return PaginatedComponent(
          type: TileType.grid,
          reloadToken: _reloadToken,
          onRefresh: widget.provider.refresh,
          fetchPage:
              (page, size) => widget.provider.fetchPage(
                _query,
                _sortField,
                _ascending,
                _localOnly,
                page,
                size,
              ),
          isSelected: (entity) => selected.contains(entity),
          onTap: (entity, items) async {
            if (selected.isNotEmpty) {
              if (selected.contains(entity)) {
                selectionProvider.deselectEntity(entity);
              } else {
                selectionProvider.selectEntity(entity);
              }
              return;
            }
            await widget.onEntityTap(entity, items, context);
          },
          onLongPress: (entity, items) {
            if (selected.contains(entity)) {
              selectionProvider.deselectEntity(entity);
            } else {
              selectionProvider.selectEntity(entity);
            }
          },
          actions: [
            // [0] main action
            (entity) {
              if (selected.contains(entity)) {
                return const Icon(
                  FluentIcons.checkCircleOn,
                  color: Colors.white,
                );
              }
              if (selected.isNotEmpty) {
                return const Icon(
                  FluentIcons.checkCircleOff,
                  color: Colors.white,
                );
              }
              return widget.buildMainAction(entity, context);
            },
            // [1] secondary action
            (entity) {
              if (selected.contains(entity)) return const SizedBox.shrink();
              return widget.buildLeftAction(entity, context);
            },
            // [2+] extra dropdown items
            for (final actionFn in widget.extraActions)
              (entity) => actionFn(entity, context),
          ],
          onDropdownSelected:
              (entity, i) => widget.onDropdownAction(entity, i, context),
          buildExtraTile:
              widget.buildExtraTile == null
                  ? null
                  : () => widget.buildExtraTile!(context),
        );
      },
    );
  }
}
