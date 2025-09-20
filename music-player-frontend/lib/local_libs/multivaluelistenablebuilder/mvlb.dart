import 'package:flutter/foundation.dart' show Listenable, ValueListenable;
import 'package:flutter/material.dart' show AnimatedBuilder, BuildContext, StatelessWidget, Widget;

class MultiValueListenableBuilder extends StatelessWidget {
  final List<ValueListenable> valueListenables;
  final Widget Function(
      BuildContext context, List<dynamic> values, Widget? child) builder;
  final Widget? child;

  const MultiValueListenableBuilder({
    super.key,
    required this.valueListenables,
    required this.builder,
    this.child,
  })  : assert(valueListenables.length != 0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(valueListenables),
      builder: (context, child) {
        final list = valueListenables.map((listenable) => listenable.value);
        return builder(context, List<dynamic>.unmodifiable(list), child);
      },
      child: child,
    );
  }
}