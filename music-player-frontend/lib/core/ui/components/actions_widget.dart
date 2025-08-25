import 'package:flutter/material.dart';

class ActionsWidget extends StatefulWidget {
  const ActionsWidget({super.key});

  @override
  State<ActionsWidget> createState() => _ActionsWidgetState();
}

class _ActionsWidgetState extends State<ActionsWidget> {
  ValueNotifier<bool> expanded = ValueNotifier(false);

  Widget _buildActions(bool expanded) {
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {

    return ValueListenableBuilder(
      valueListenable: expanded,
      builder: (context, value, child) {
        return _buildActions(value);
      },
    );

  }
}
