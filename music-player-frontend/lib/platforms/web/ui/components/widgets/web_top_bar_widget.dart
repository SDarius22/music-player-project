import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/ui/components/widgets/top_bar_widget.dart';

class WebAppBarWidget extends AbstractAppBarWidget {
  const WebAppBarWidget({super.key, super.actions = const []});

  @override
  Widget buildAppBar(BuildContext context) {
    return Container();
  }
}
