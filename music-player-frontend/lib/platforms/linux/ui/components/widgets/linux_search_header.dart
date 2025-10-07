import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/linux_scaler.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/theme.dart';

class LinuxSearchHeader extends StatefulWidget {
  const LinuxSearchHeader({
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
  State<StatefulWidget> createState() => _LinuxSearchHeaderState();
}

class _LinuxSearchHeaderState extends State<LinuxSearchHeader> {
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
    var height = MediaQuery.of(context).size.height;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            focusNode: searchNode,
            controller: _controller,
            style: TextStyle(color: Colors.white, fontSize: height * 0.02),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              hintText: widget.title,
              hintStyle: TextStyle(
                color: Colors.white,
                fontSize: height * 0.025,
                fontWeight: FontWeight.bold,
              ),
              border: InputBorder.none,
              prefixIcon: Icon(
                FluentIcons.search,
                color: Colors.white,
                size: height * 0.025,
              ),
              suffixIcon:
                  searchNode.hasFocus
                      ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.white,
                          size: height * 0.025,
                        ),
                        onPressed: () {
                          _controller.clear();
                          widget.provider.setQuery("");
                          searchNode.unfocus();
                        },
                      )
                      : null,
              contentPadding: EdgeInsets.symmetric(vertical: height * 0.005),
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
          padding: EdgeInsets.all(height * 0.005),
          icon: Icon(
            FluentIcons.play,
            color: Colors.white,
            size: height * 0.025,
          ),
        ),
        IconButton(
          tooltip: "Shuffle",
          onPressed: () async {},
          padding: EdgeInsets.all(height * 0.005),
          icon: Icon(
            FluentIcons.shuffleOn,
            color: Colors.white,
            size: height * 0.025,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: "Sort",
          icon: Icon(
            _isAscending
                ? FluentIcons.sortAscending
                : FluentIcons.sortDescending,
            color: Colors.white,
            size: LinuxScaler.scale(context, 24),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              MediaQuery.of(context).size.height * 0.015,
            ),
          ),
          menuPadding: EdgeInsets.all(LinuxScaler.scale(context, 8)),
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    "Sort By",
                    style: MusicPlayerTheme.getTheme(
                      context,
                    ).textTheme.titleMedium!.copyWith(color: Colors.grey),
                  ),
                ),
                const PopupMenuDivider(),
                ...widget.provider.sortFields.keys.map(
                  (field) => _buildSortMenuItem(context, field),
                ),
                // _buildSortMenuItem(context, "Title"),
                // // _buildSortMenuItem(context, "Artist", "artist"),
                // // _buildSortMenuItem(context, "Album", "album"),
                // _buildSortMenuItem(context, "Duration"),
                // _buildSortMenuItem(context, "Date Added"),
                const PopupMenuDivider(),
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(
                        _isAscending
                            ? FluentIcons.sortAscending
                            : FluentIcons.sortDescending,
                        color: Colors.white,
                        size: LinuxScaler.scale(context, 16),
                      ),
                      SizedBox(width: LinuxScaler.scale(context, 8)),
                      Text(
                        _isAscending ? "Ascending" : "Descending",
                        style:
                            MusicPlayerTheme.getTheme(
                              context,
                            ).textTheme.bodyMedium!,
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
            size: LinuxScaler.scale(context, 16),
          ),
          SizedBox(width: LinuxScaler.scale(context, 8)),
          Text(
            value,
            style:
                isSelected
                    ? MusicPlayerTheme.getTheme(context).textTheme.titleMedium
                    : MusicPlayerTheme.getTheme(
                      context,
                    ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
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
