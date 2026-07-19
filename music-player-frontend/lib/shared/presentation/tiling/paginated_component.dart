import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/shared/presentation/layout/app_layout.dart';
import 'package:music_player_frontend/features/library/presentation/providers/queryable_provider.dart';
import 'package:music_player_frontend/shared/presentation/tiling/custom_tile_component.dart';
import 'package:music_player_frontend/shared/presentation/tiling/tile_type.dart';

typedef PageFetcher = Future<PageResult> Function(int page, int size);

class PaginatedComponent extends StatefulWidget {
  final TileType type;
  final PageFetcher fetchPage;
  final Future<void> Function()? onRefresh;
  final int pageSize;
  final Object reloadToken;
  final Future<void> Function(BaseEntity entity, List<dynamic> items) onTap;
  final void Function(BaseEntity entity, List<dynamic> items) onLongPress;
  final bool Function(BaseEntity) isSelected;
  final Function(BaseEntity)? enrichEntity;
  final String emptyText;

  // actions[0]=main, actions[1]=secondary, actions[2+]=dropdown item display widgets
  final List<Widget Function(BaseEntity)> actions;

  // Fires when dropdown item i (0-based) is tapped on the tile for entity.
  final void Function(BaseEntity entity, int dropdownIndex)? onDropdownSelected;
  final bool Function(BaseEntity entity, int dropdownIndex)?
  isDropdownActionVisible;
  final Widget Function()? buildExtraTile; // grid/wide only
  final double? itemExtent; // list only

  // Delay before kicking off the first page fetch. Lets the host screen
  // paint before any synchronous DB work on the main isolate blocks the UI.
  final Duration initialLoadDelay;

  const PaginatedComponent({
    super.key,
    required this.type,
    required this.fetchPage,
    required this.onTap,
    required this.onLongPress,
    required this.isSelected,
    required this.reloadToken,
    this.onRefresh,
    this.pageSize = 50,
    this.enrichEntity,
    this.emptyText = 'No items found',
    this.actions = const [],
    this.onDropdownSelected,
    this.isDropdownActionVisible,
    this.buildExtraTile,
    this.itemExtent,
    this.initialLoadDelay = Duration.zero,
  });

  @override
  State<PaginatedComponent> createState() => _PaginatedComponentState();
}

class _PaginatedComponentState extends State<PaginatedComponent> {
  late final ScrollController _scrollController;
  late final _PaginationController _controller;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _controller = _PaginationController(
      fetchPage: widget.fetchPage,
      pageSize: widget.pageSize,
    );
    if (widget.initialLoadDelay == Duration.zero) {
      _controller.loadPage(0, reset: true);
    } else {
      Future.delayed(widget.initialLoadDelay, () {
        if (!mounted) return;
        _controller.loadPage(0, reset: true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant PaginatedComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fetchPage != oldWidget.fetchPage ||
        widget.pageSize != oldWidget.pageSize) {
      _controller.updateConfig(
        fetchPage: widget.fetchPage,
        pageSize: widget.pageSize,
      );
    }

    if (widget.reloadToken != oldWidget.reloadToken) {
      _controller.loadPage(0, reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchNextPage();
    }
  }

  void _fetchNextPage() {
    final state = _controller.state;
    if (!state.hasMore || state.isLoading) return;
    _controller.loadPage(state.currentPage + 1);
  }

  Future<void> _refresh() async {
    if (widget.onRefresh != null) await widget.onRefresh!.call();
    await _controller.loadPage(0, reset: true);
  }

  Widget _buildContent(BuildContext context, _PagedState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.items.isEmpty && widget.type == TileType.list) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            widget.emptyText,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;

    if (widget.type == TileType.list) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.contentInset(width),
        ),
        sliver: CustomTileComponent(
          tileType: TileType.list,
          items: state.items,
          actions: widget.actions,
          onDropdownSelected: widget.onDropdownSelected,
          isDropdownActionVisible: widget.isDropdownActionVisible,
          showEnrichLoadingPlaceholder: false,
          isSelected: widget.isSelected,
          onTap: (entity) => widget.onTap(entity, state.items),
          onLongPress: (entity) => widget.onLongPress(entity, state.items),
          enrichEntity: widget.enrichEntity,
          itemExtent: widget.itemExtent ?? 72,
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: AppLayout.contentInset(width)),
      sliver: CustomTileComponent(
        tileType: widget.type,
        items: state.items,
        actions: widget.actions,
        onDropdownSelected: widget.onDropdownSelected,
        isDropdownActionVisible: widget.isDropdownActionVisible,
        showEnrichLoadingPlaceholder: false,
        isSelected: widget.isSelected,
        onTap: (entity) => widget.onTap(entity, state.items),
        onLongPress: (entity) => widget.onLongPress(entity, state.items),
        buildExtraTile: widget.buildExtraTile,
        enrichEntity: widget.enrichEntity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildContent(context, state),
              if (state.isLoading && state.items.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (state.error != null &&
                  !state.isLoading &&
                  state.items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: TextButton(
                        onPressed:
                            () => _controller.loadPage(state.currentPage + 1),
                        child: const Text('Failed to load more. Tap to retry.'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PaginationController extends ChangeNotifier {
  _PaginationController({required PageFetcher fetchPage, required int pageSize})
    : _fetchPage = fetchPage,
      _pageSize = pageSize;

  PageFetcher _fetchPage;
  int _pageSize;
  int _requestId = 0;
  bool _disposed = false;
  _PagedState _state = const _PagedState();

  _PagedState get state => _state;

  void updateConfig({required PageFetcher fetchPage, required int pageSize}) {
    _fetchPage = fetchPage;
    _pageSize = pageSize;
  }

  Future<void> loadPage(int page, {bool reset = false}) async {
    if (_state.isLoading) return;

    final requestId = ++_requestId;
    _updateState(_state.copyWith(isLoading: true, clearError: true));

    try {
      final result = await _fetchPage(page, _pageSize);
      if (_disposed || requestId != _requestId) return;

      final mergedItems =
          reset
              ? List<dynamic>.from(result.content)
              : <dynamic>[..._state.items, ...result.content];

      _updateState(
        _state.copyWith(
          items: mergedItems,
          currentPage: result.page,
          hasMore: result.page < result.totalPages - 1,
          isLoading: false,
        ),
      );
    } catch (e) {
      if (_disposed || requestId != _requestId) return;
      debugPrint('PaginatedComponent: loadPage error: $e');
      _updateState(_state.copyWith(isLoading: false, error: e));
    }
  }

  void _updateState(_PagedState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _PagedState {
  final List<dynamic> items;
  final int currentPage;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  const _PagedState({
    this.items = const [],
    this.currentPage = 0,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  _PagedState copyWith({
    List<dynamic>? items,
    int? currentPage,
    bool? isLoading,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return _PagedState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
