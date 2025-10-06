import 'package:flutter/material.dart';

abstract class AbstractAppBarWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final List<Widget> actions;

  const AbstractAppBarWidget({super.key, this.actions = const []});

  Widget buildAppBar(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return buildAppBar(context);
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}
