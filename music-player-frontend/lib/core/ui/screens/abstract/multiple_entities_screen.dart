import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/providers/selection_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_component.dart';
import 'package:music_player_frontend/core/ui/components/widgets/search_header.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

abstract class MultipleEntitiesScreen<T extends QueryableProvider>
    extends StatefulWidget {
  final T provider;

  const MultipleEntitiesScreen({super.key, required this.provider});

  String? get screenTitle => null;

  Widget buildLeftAction(BaseEntity entity, BuildContext context) =>
      const SizedBox.shrink();

  Widget buildMainAction(BaseEntity entity, BuildContext context) =>
      const SizedBox.shrink();

  Widget buildRightAction(BaseEntity entity, BuildContext context) =>
      const SizedBox.shrink();

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
  late bool _ascending;
  String _query = '';
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  final List<dynamic> _items = [];
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _sortField = widget.provider.sortFields.keys.firstOrNull ?? 'Name';
    _ascending = true;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    (widget.provider as ChangeNotifier).addListener(_onProviderChanged);
    _fetchPage(0, reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    (widget.provider as ChangeNotifier).removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    _fetchPage(0, reset: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchNextPage();
    }
  }

  void _fetchNextPage() {
    if (!_hasMore || _isLoading) return;
    _fetchPage(_currentPage + 1);
  }

  Future<void> _fetchPage(int page, {bool reset = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result = await widget.provider.fetchPage(
        _query,
        _sortField,
        _ascending,
        page,
        30,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.content);
        _currentPage = result.page;
        _hasMore = result.page < result.totalPages - 1;
      });
    } catch (e) {
      debugPrint('MultipleEntitiesScreen: fetchPage error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onQuery(String q) {
    _query = q;
    _fetchPage(0, reset: true);
  }

  void _onSortField(String field) {
    _sortField = field;
    _fetchPage(0, reset: true);
  }

  void _onAscending(bool asc) {
    _ascending = asc;
    _fetchPage(0, reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.screenTitle;
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return GlassScaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (title != null)
            Container(
              height: height * 0.065,
              width: width,
              padding: EdgeInsets.symmetric(horizontal: width * 0.01),
              child: SearchHeader(
                title: title,
                sortFields: widget.provider.sortFields,
                initialSortField: _sortField,
                initialAscending: _ascending,
                onQuery: _onQuery,
                onSortField: _onSortField,
                onAscending: _onAscending,
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await widget.provider.refresh();
                await _fetchPage(0, reset: true);
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: width * 0.01,
                      right: width * 0.01,
                    ),
                    sliver: _buildGrid(context),
                  ),
                  if (_isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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
        return CustomGridComponent(
          items: _items,
          isSelected: (entity) => selected.contains(entity),
          onTap: (entity) async {
            if (selected.isNotEmpty) {
              if (selected.contains(entity)) {
                selectionProvider.deselectEntity(entity);
              } else {
                selectionProvider.selectEntity(entity);
              }
              return;
            }
            await widget.onEntityTap(entity, _items, context);
          },
          onLongPress: (entity) {
            if (selected.contains(entity)) {
              selectionProvider.deselectEntity(entity);
            } else {
              selectionProvider.selectEntity(entity);
            }
          },
          buildLeftAction: (entity) {
            if (selected.contains(entity)) return const SizedBox.shrink();
            return widget.buildLeftAction(entity, context);
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
            return widget.buildMainAction(entity, context);
          },
          buildRightAction: (entity) {
            if (selected.contains(entity)) return const SizedBox.shrink();
            return widget.buildRightAction(entity, context);
          },
          buildExtraTile:
              widget.buildExtraTile == null
                  ? null
                  : () => widget.buildExtraTile!(context),
        );
      },
    );
  }
}
