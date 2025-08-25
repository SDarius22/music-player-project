import 'package:flutter/material.dart';

abstract class AbstractAppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> actions;

  const AbstractAppBarWidget({
    super.key,
    this.actions = const [],
  });

  Widget _buildAppBar();

  @override
  Widget build(BuildContext context) {
    return _buildAppBar();
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}