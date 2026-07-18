import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class SearchHeader extends StatefulWidget {
  const SearchHeader({
    super.key,
    required this.title,
    required this.sortFields,
    required this.initialSortField,
    required this.initialAscending,
    required this.initialLocalOnly,
    this.initialStreamOnly = false,
    required this.onQuery,
    required this.onSortField,
    required this.onAscending,
    required this.onLocalOnly,
    this.onStreamOnly,
    this.clickedPlayAll,
    this.clickedShuffle,
  });

  final String title;
  final Map<String, dynamic> sortFields;
  final String initialSortField;
  final bool initialAscending;
  final bool initialLocalOnly;
  final bool initialStreamOnly;
  final void Function(String) onQuery;
  final void Function(String) onSortField;
  final void Function(bool) onAscending;
  final void Function(bool) onLocalOnly;
  final void Function(bool)? onStreamOnly;
  final void Function()? clickedPlayAll;
  final void Function()? clickedShuffle;

  @override
  State<StatefulWidget> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<SearchHeader> {
  FocusNode searchNode = FocusNode();
  Timer? _debounce;
  final TextEditingController _controller = TextEditingController();
  late String _sortField;
  late bool _localOnly;
  late bool _streamOnly;
  late bool _isAscending;

  @override
  void initState() {
    super.initState();
    _localOnly = widget.initialLocalOnly;
    _streamOnly = widget.initialStreamOnly;
    _sortField = widget.initialSortField;
    _isAscending = widget.initialAscending;
  }

  @override
  void didUpdateWidget(covariant SearchHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLocalOnly != widget.initialLocalOnly) {
      _localOnly = widget.initialLocalOnly;
    }
    if (oldWidget.initialStreamOnly != widget.initialStreamOnly) {
      _streamOnly = widget.initialStreamOnly;
    }
    if (oldWidget.initialSortField != widget.initialSortField) {
      _sortField = widget.initialSortField;
    }
    if (oldWidget.initialAscending != widget.initialAscending) {
      _isAscending = widget.initialAscending;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    searchNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            focusNode: searchNode,
            controller: _controller,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(color: Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              hintText: widget.title,
              hintStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              border: InputBorder.none,
              prefixIcon: const Icon(
                FluentIcons.search,
                color: Colors.white,
                size: 24,
              ),
              suffixIcon:
                  _controller.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(
                          FluentIcons.clear,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () {
                          _controller.clear();
                          widget.onQuery('');
                          searchNode.unfocus();
                        },
                      )
                      : null,
              contentPadding: EdgeInsets.symmetric(
                vertical: MediaQuery.of(context).size.height * 0.005,
              ),
            ),
            onChanged: (value) {
              if (_debounce?.isActive ?? false) _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () {
                widget.onQuery(value);
              });
            },
          ),
        ),
        IconButton(
          tooltip: "Play All",
          onPressed: widget.clickedPlayAll ?? () {},
          icon: const Icon(FluentIcons.play, color: Colors.white, size: 24),
        ),
        IconButton(
          tooltip: "Shuffle",
          onPressed: widget.clickedShuffle ?? () {},
          icon: const Icon(
            FluentIcons.shuffleOn,
            color: Colors.white,
            size: 24,
          ),
        ),
        ValueListenableBuilder(
          valueListenable:
              context.read<AbstractAppStateProvider>().shouldDisplayLocalOnly,
          builder: (context, shouldDisplayLocalOnly, child) {
            final effectiveLocalOnly = shouldDisplayLocalOnly || _localOnly;
            return PopupMenuButton<String>(
              tooltip: "Filter",
              constraints: const BoxConstraints(minWidth: 300),
              icon: const Icon(
                FluentIcons.filter,
                color: Colors.white,
                size: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  MediaQuery.of(context).size.height * 0.015,
                ),
              ),
              menuPadding: const EdgeInsets.all(8),
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        "Filter",
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium!.copyWith(color: Colors.grey),
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      enabled: !shouldDisplayLocalOnly,
                      onTap: () {
                        setState(() {
                          _localOnly = !_localOnly;
                        });
                        widget.onLocalOnly(_localOnly);
                      },
                      child: Row(
                        children: [
                          Icon(
                            effectiveLocalOnly
                                ? FluentIcons.checkCircleOn
                                : FluentIcons.checkCircleOff,
                            color:
                                effectiveLocalOnly
                                    ? Colors.blue
                                    : Colors.transparent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Available Offline",
                            style:
                                effectiveLocalOnly
                                    ? Theme.of(context).textTheme.titleMedium
                                    : Theme.of(context).textTheme.bodyMedium!
                                        .copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      onTap: () {
                        setState(() {
                          _streamOnly = !_streamOnly;
                        });
                        widget.onStreamOnly?.call(_streamOnly);
                      },
                      child: Row(
                        children: [
                          Icon(
                            _streamOnly
                                ? FluentIcons.checkCircleOn
                                : FluentIcons.checkCircleOff,
                            color:
                                _streamOnly ? Colors.blue : Colors.transparent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Available to Stream",
                            style:
                                _streamOnly
                                    ? Theme.of(context).textTheme.titleMedium
                                    : Theme.of(context).textTheme.bodyMedium!
                                        .copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
            );
          },
        ),

        PopupMenuButton<String>(
          tooltip: "Sort",
          icon: Icon(
            _isAscending
                ? FluentIcons.sortAscending
                : FluentIcons.sortDescending,
            color: Colors.white,
            size: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              MediaQuery.of(context).size.height * 0.015,
            ),
          ),
          menuPadding: const EdgeInsets.all(8),
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    "Sort By",
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium!.copyWith(color: Colors.grey),
                  ),
                ),
                const PopupMenuDivider(),
                ...widget.sortFields.keys.map(
                  (field) => _buildSortMenuItem(context, field),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(
                        _isAscending
                            ? FluentIcons.sortAscending
                            : FluentIcons.sortDescending,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isAscending ? "Ascending" : "Descending",
                        style: Theme.of(context).textTheme.bodyMedium!,
                      ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      _isAscending = !_isAscending;
                    });
                    widget.onAscending(_isAscending);
                  },
                ),
              ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(BuildContext context, String value) {
    final isSelected = _sortField == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            isSelected ? FluentIcons.checkCircleOn : FluentIcons.checkCircleOff,
            color: isSelected ? Colors.blue : Colors.transparent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style:
                isSelected
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(
                      context,
                    ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
          ),
        ],
      ),
      onTap: () {
        setState(() {
          _sortField = value;
        });
        widget.onSortField(value);
      },
    );
  }
}
