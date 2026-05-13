import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/custom_tile_component.dart';
import 'package:music_player_frontend/core/ui/components/tiling/tile_type.dart';

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
  final Widget Function()? buildExtraTile; // grid/wide only
  final double? itemExtent; // list only

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
    this.buildExtraTile,
    this.itemExtent,
  });

  @override
  State<PaginatedComponent> createState() => _PaginatedComponentState();
}

class _PaginatedComponentState extends State<PaginatedComponent> {
  late final ScrollController _scrollController;
  _PagedState _state = const _PagedState();
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadPage(0, reset: true);
  }

  @override
  void didUpdateWidget(covariant PaginatedComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadToken != oldWidget.reloadToken) {
      _loadPage(0, reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchNextPage();
    }
  }

  void _fetchNextPage() {
    if (!_state.hasMore || _state.isLoading) return;
    _loadPage(_state.currentPage + 1);
  }

  Future<void> _refresh() async {
    if (widget.onRefresh != null) await widget.onRefresh!.call();
    await _loadPage(0, reset: true);
  }

  Future<void> _loadPage(int page, {bool reset = false}) async {
    if (_state.isLoading) return;

    final requestId = ++_requestId;
    setState(() {
      _state = _state.copyWith(isLoading: true, clearError: true);
    });

    try {
      final result = await widget.fetchPage(page, widget.pageSize);
      if (!mounted || requestId != _requestId) return;

      final mergedItems =
          reset
              ? List<dynamic>.from(result.content)
              : <dynamic>[..._state.items, ...result.content];

      setState(() {
        _state = _state.copyWith(
          items: mergedItems,
          currentPage: result.page,
          hasMore: result.page < result.totalPages - 1,
          isLoading: false,
        );
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      debugPrint('PaginatedComponent: loadPage error: $e');
      setState(() {
        _state = _state.copyWith(isLoading: false, error: e);
      });
    }
  }

  Widget _buildContent(BuildContext context) {
    if (_state.isLoading && _state.items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_state.items.isEmpty && widget.type == TileType.list) {
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
        padding: EdgeInsets.only(left: width * 0.01, right: width * 0.01),
        sliver: CustomTileComponent(
          tileType: TileType.list,
          items: _state.items,
          actions: widget.actions,
          onDropdownSelected: widget.onDropdownSelected,
          isSelected: widget.isSelected,
          onTap: (entity) => widget.onTap(entity, _state.items),
          onLongPress: (entity) => widget.onLongPress(entity, _state.items),
          enrichEntity: widget.enrichEntity,
          itemExtent: widget.itemExtent ?? 72,
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.only(left: width * 0.01, right: width * 0.01),
      sliver: CustomTileComponent(
        tileType: widget.type,
        items: _state.items,
        actions: widget.actions,
        onDropdownSelected: widget.onDropdownSelected,
        isSelected: widget.isSelected,
        onTap: (entity) => widget.onTap(entity, _state.items),
        onLongPress: (entity) => widget.onLongPress(entity, _state.items),
        buildExtraTile: widget.buildExtraTile,
        enrichEntity: widget.enrichEntity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildContent(context),
          if (_state.isLoading && _state.items.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_state.error != null &&
              !_state.isLoading &&
              _state.items.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: TextButton(
                    onPressed: () => _loadPage(_state.currentPage + 1),
                    child: const Text('Failed to load more. Tap to retry.'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
