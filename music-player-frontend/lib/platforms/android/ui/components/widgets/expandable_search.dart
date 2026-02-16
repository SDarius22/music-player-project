import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';

class ExpandableSearch extends StatefulWidget {
  const ExpandableSearch({super.key, required this.provider});

  final QueryableProvider provider;

  @override
  State<ExpandableSearch> createState() => _ExpandableSearchState();
}

class _ExpandableSearchState extends State<ExpandableSearch> {
  bool _isExpanded = false;
  FocusNode searchNode = FocusNode();
  Timer? _debounce;
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      child:
          _isExpanded
              ? SizedBox(
                width: width * 0.9,
                child: TextFormField(
                  focusNode: searchNode,
                  controller: _controller,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: height * 0.02,
                  ),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
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
                            : Icon(
                              FluentIcons.search,
                              color: Colors.white,
                              size: height * 0.025,
                            ),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: height * 0.005,
                    ),
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
              )
              : IconButton(
                icon: const Icon(FluentIcons.search, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isExpanded = true;
                  });
                },
              ),
    );
  }
}
