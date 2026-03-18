import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
class SearchHeader extends StatefulWidget {
  const SearchHeader({
    super.key,
    required this.title,
    required this.provider,
    this.clickedPlayAll,
    this.clickedShuffle,
  });

  final String title;
  final QueryableProvider provider;
  final void Function()? clickedPlayAll;
  final void Function()? clickedShuffle;

  @override
  State<StatefulWidget> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<SearchHeader> {
  FocusNode searchNode = FocusNode();
  Timer? _debounce;
  final TextEditingController _controller = TextEditingController();
  String _sortField = "Name";
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _sortField = widget.provider.getSortField();
    _isAscending = widget.provider.getFlag();
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
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white),
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
                          Icons.clear,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () {
                          _controller.clear();
                          widget.provider.setQuery("");
                          searchNode.unfocus();
                        },
                      )
                      : null,
              contentPadding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.005),
            ),
            onChanged: (value) {
              if (_debounce?.isActive ?? false) {
                _debounce?.cancel();
              }
              _debounce = Timer(const Duration(milliseconds: 500), () {
                widget.provider.setQuery(value);
              });
            },
          ),
        ),
        IconButton(
          tooltip: "Play All",
          onPressed: () async {},
          icon: const Icon(
            FluentIcons.play,
            color: Colors.white,
            size: 24,
          ),
        ),
        IconButton(
          tooltip: "Shuffle",
          onPressed: () async {},
          icon: const Icon(
            FluentIcons.shuffleOn,
            color: Colors.white,
            size: 24,
          ),
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
          menuPadding: EdgeInsets.all(8),
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    "Sort By",
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Colors.grey),
                  ),
                ),
                const PopupMenuDivider(),
                ...widget.provider.sortFields.keys.map(
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
                      SizedBox(width: 8),
                      Text(
                        _isAscending ? "Ascending" : "Descending",
                        style:
                            Theme.of(context).textTheme.bodyMedium!,
                      ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      _isAscending = !_isAscending;
                      widget.provider.setFlag(_isAscending);
                    });
                  },
                ),
              ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(BuildContext context, String value) {
    bool isSelected = _sortField == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            isSelected ? FluentIcons.checkCircleOn : FluentIcons.checkCircleOff,
            color: isSelected ? Colors.blue : Colors.transparent,
            size: 16,
          ),
          SizedBox(width: 8),
          Text(
            value,
            style:
                isSelected
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.grey),
          ),
        ],
      ),
      onTap: () {
        setState(() {
          _sortField = value;
          widget.provider.setSortField(_sortField);
        });
      },
    );
  }
}
