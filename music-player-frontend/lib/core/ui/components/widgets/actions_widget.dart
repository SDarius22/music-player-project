import 'package:flutter/material.dart';

class ActionsWidget extends StatefulWidget {
  const ActionsWidget({super.key});

  @override
  State<ActionsWidget> createState() => ActionsWidgetState();
}

class ActionsWidgetState extends State<ActionsWidget> {
  ValueNotifier<bool> expanded = ValueNotifier(false);

  Widget buildContent(BuildContext context) {
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    return buildContent(context);
  }
}
