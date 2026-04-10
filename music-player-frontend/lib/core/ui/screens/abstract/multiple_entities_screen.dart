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
  static const int _pageSize = 30;

  late String _sortField;
  late bool _ascending;
  String _query = '';
  late ScrollController _scrollController;
  late final ValueNotifier<_PagedViewState> _viewState;
  late final ValueNotifier<Future<void>> _loadFuture;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _sortField = widget.provider.sortFields.keys.firstOrNull ?? 'Name';
    _ascending = true;
    _viewState = ValueNotifier<_PagedViewState>(const _PagedViewState());
    _loadFuture = ValueNotifier<Future<void>>(Future.value());
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    (widget.provider as ChangeNotifier).addListener(_onProviderChanged);
    _runLoad(() => _fetchPage(0, reset: true));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _viewState.dispose();
    _loadFuture.dispose();
    (widget.provider as ChangeNotifier).removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    _runLoad(() => _fetchPage(0, reset: true));
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchNextPage();
    }
  }

  void _fetchNextPage() {
    final state = _viewState.value;
    if (!state.hasMore || state.isLoading) return;
    _runLoad(() => _fetchPage(state.currentPage + 1));
  }

  Future<void> _fetchPage(int page, {bool reset = false}) async {
    final state = _viewState.value;
    if (state.isLoading) return;

    final requestId = ++_requestId;
    _viewState.value = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await widget.provider.fetchPage(
        _query,
        _sortField,
        _ascending,
        page,
        _pageSize,
      );
      if (!mounted || requestId != _requestId) return;

      final current = _viewState.value;
      final nextItems =
          reset
              ? List<dynamic>.from(result.content)
              : <dynamic>[...current.items, ...result.content];

      _viewState.value = current.copyWith(
        items: nextItems,
        currentPage: result.page,
        hasMore: result.page < result.totalPages - 1,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      debugPrint('MultipleEntitiesScreen: fetchPage error: $e');
      _viewState.value = _viewState.value.copyWith(
        isLoading: false,
        error: e,
      );
    }
  }

  void _runLoad(Future<void> Function() action) {
    _loadFuture.value = action();
  }

  void _onQuery(String q) {
    _query = q;
    _runLoad(() => _fetchPage(0, reset: true));
  }

  void _onSortField(String field) {
    _sortField = field;
    _runLoad(() => _fetchPage(0, reset: true));
  }

  void _onAscending(bool asc) {
    _ascending = asc;
    _runLoad(() => _fetchPage(0, reset: true));
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
                _runLoad(() => _fetchPage(0, reset: true));
                await _loadFuture.value;
              },
              child: ValueListenableBuilder<Future<void>>(
                valueListenable: _loadFuture,
                builder: (context, future, _) {
                  return FutureBuilder<void>(
                    future: future,
                    builder: (context, snapshot) {
                      return ValueListenableBuilder<_PagedViewState>(
                        valueListenable: _viewState,
                        builder: (context, state, _) {
                          return CustomScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              if (snapshot.connectionState == ConnectionState.waiting &&
                                  state.items.isEmpty)
                                const SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: EdgeInsets.only(
                                    left: width * 0.01,
                                    right: width * 0.01,
                                  ),
                                  sliver: _buildGrid(context, state),
                                ),
                              if (state.isLoading && state.items.isNotEmpty)
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, _PagedViewState state) {
    final selectionProvider = Provider.of<SelectionProvider>(
      context,
      listen: false,
    );
    return Selector<SelectionProvider, Set<BaseEntity>>(
      selector: (context, p) => p.selectedEntities,
      builder: (context, selected, child) {
        return CustomGridComponent(
          items: state.items,
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
            await widget.onEntityTap(entity, state.items, context);
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

class _PagedViewState {
  final List<dynamic> items;
  final int currentPage;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  const _PagedViewState({
    this.items = const [],
    this.currentPage = 0,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  _PagedViewState copyWith({
    List<dynamic>? items,
    int? currentPage,
    bool? isLoading,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return _PagedViewState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

