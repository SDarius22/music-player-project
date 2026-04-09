import 'package:flutter/cupertino.dart';

Route<T> buildFadeRoute<T>(
  Widget Function(BuildContext, Animation<double>, Animation<double>)
  pageBuilder, {
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 500),
    pageBuilder: pageBuilder,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
