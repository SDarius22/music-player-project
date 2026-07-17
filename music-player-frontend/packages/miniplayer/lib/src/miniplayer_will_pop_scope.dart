import 'package:flutter/material.dart';

class MiniplayerWillPopScope extends StatefulWidget {
  const MiniplayerWillPopScope({
    super.key,
    required this.child,
    required this.onWillPop,
  });

  final Widget child;
  final Future<bool> Function() onWillPop;

  @override
  State<MiniplayerWillPopScope> createState() => MiniplayerWillPopScopeState();

  static MiniplayerWillPopScopeState? of(BuildContext context) {
    return context.findAncestorStateOfType<MiniplayerWillPopScopeState>();
  }
}

class MiniplayerWillPopScopeState extends State<MiniplayerWillPopScope> {
  MiniplayerWillPopScopeState? _descendant;

  set descendant(MiniplayerWillPopScopeState? state) {
    _descendant = state;
  }

  Future<bool> onWillPop() async {
    bool? willPop;
    if (_descendant != null) {
      willPop = await _descendant!.onWillPop();
    }
    if (willPop == null || willPop) {
      willPop = await widget.onWillPop();
    }
    return willPop;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var parentGuard = MiniplayerWillPopScope.of(context);
    if (parentGuard != null) {
      parentGuard.descendant = this;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;

        final NavigatorState navigator = Navigator.of(context);
        final bool shouldPop = await onWillPop();
        if (shouldPop && mounted) {
          navigator.pop(result);
        }
      },
      child: widget.child,
    );
  }
}
