import 'package:flutter/material.dart';

abstract class ResponsiveScreen<T> extends StatelessWidget {
  const ResponsiveScreen({super.key});

  double get compactBreakpoint => 600;

  bool isCompactLayout(BoxConstraints constraints) {
    return constraints.maxWidth < compactBreakpoint;
  }

  Widget buildResponsiveBody(BuildContext context, T data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isCompactLayout(constraints)) {
          return buildCompactBody(context, data, constraints);
        }
        return buildExpandedBody(context, data, constraints);
      },
    );
  }

  Widget buildCompactBody(
    BuildContext context,
    T data,
    BoxConstraints constraints,
  );

  Widget buildExpandedBody(
    BuildContext context,
    T data,
    BoxConstraints constraints,
  );
}
