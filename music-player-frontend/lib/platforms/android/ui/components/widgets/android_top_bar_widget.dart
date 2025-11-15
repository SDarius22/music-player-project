import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/widgets/top_bar_widget.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:provider/provider.dart';

class AppBarWidget extends AbstractAppBarWidget {
  final String title;
  final Widget? leading;

  const AppBarWidget({
    super.key,
    required this.title,
    this.leading,
    super.actions,
  });

  @override
  Widget buildAppBar(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return ValueListenableBuilder(
      valueListenable: context.read<AbstractAppStateProvider>().opacityNotifier,
      builder: (context, appBarOpacity, child) {
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: appBarOpacity,
          child: GlassContainer(
            height: MediaQuery.of(context).padding.top + kToolbarHeight,
            width: width,
            color: Colors.black.withValues(alpha: 0.4),
            borderColor: Colors.transparent,
            blur: 45.0,
            borderWidth: 0.0,
            elevation: 0.0,
            alignment: Alignment.center,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) leading!,
                  SizedBox(width: width * 0.025),
                  Text(
                    title,
                    style: MusicPlayerTheme.getTheme(
                      context,
                      context.read<Scaler>(),
                    ).textTheme.titleLarge!.copyWith(
                      color: Colors.white,
                      fontSize: height * 0.025,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Row(mainAxisSize: MainAxisSize.min, children: actions),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
