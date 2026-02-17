import 'package:flutter/material.dart';

/// A widget that lets the miniplayer (and nested miniplayers) intercept back
/// navigation.
///
/// This is a modern replacement for the old `WillPopScope`/`addScopedWillPopCallback`
/// pattern, implemented using `PopScope`.
class MiniplayerWillPopScope extends StatefulWidget {
  const MiniplayerWillPopScope({
    super.key,
    required this.child,
    required this.onWillPop,
  });

  final Widget child;

  /// Return `true` to allow the pop, `false` to veto it.
  final Future<bool> Function() onWillPop;

  @override
  State<MiniplayerWillPopScope> createState() => _MiniplayerWillPopScopeState();

  /// Access the nearest controller in the widget tree.
  static MiniplayerWillPopController? of(BuildContext context) {
    return context.findAncestorStateOfType<_MiniplayerWillPopScopeState>();
  }
}

/// Public surface for interacting with the nearest [MiniplayerWillPopScope].
abstract class MiniplayerWillPopController {
  set descendant(MiniplayerWillPopController? state);
}

class _MiniplayerWillPopScopeState extends State<MiniplayerWillPopScope>
    implements MiniplayerWillPopController {
  _MiniplayerWillPopScopeState? _descendant;

  bool _canPop = true;

  @override
  set descendant(MiniplayerWillPopController? state) {
    _descendant = state is _MiniplayerWillPopScopeState ? state : null;
    _recomputeCanPop();
  }

  Future<bool> _handleWillPop() async {
    bool? willPop;

    // Give nested scopes first shot.
    if (_descendant != null) {
      willPop = await _descendant!._handleWillPop();
    }

    // Then fall back to this scope.
    if (willPop == null || willPop) {
      willPop = await widget.onWillPop();
    }

    return willPop;
  }

  Future<void> _recomputeCanPop() async {
    final next = await _handleWillPop();
    if (!mounted) return;
    setState(() {
      _canPop = next;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parentGuard = MiniplayerWillPopScope.of(context);
    if (parentGuard != null) {
      parentGuard.descendant = this;
    }
    _recomputeCanPop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        // If a pop already happened, nothing to do.
        if (didPop) return;

        final allow = await _handleWillPop();
        if (!mounted) return;

        if (allow) {
          if (context.mounted) {
            Navigator.of(context).pop(result);
          }
        } else {
          // Keep [canPop] in sync in case the decision changed.
          if (_canPop != false) {
            setState(() => _canPop = false);
          }
        }
      },
      child: widget.child,
    );
  }
}
