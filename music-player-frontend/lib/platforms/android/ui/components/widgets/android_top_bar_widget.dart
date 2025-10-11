import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/ui/components/widgets/top_bar_widget.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/platforms/android/ui/components/theme.dart';

class AppBarWidget extends AbstractAppBarWidget {
  final String title;
  final Widget? leading;

  const AppBarWidget({super.key, required this.title, this.leading});

  @override
  Widget buildAppBar(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return GlassContainer(
      height: kToolbarHeight,
      width: width,
      color: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      blur: 45.0,
      borderWidth: 0.0,
      elevation: 3.0,
      shadowColor: Colors.black.withOpacity(0.20),
      padding: EdgeInsets.only(bottom: height * 0.01),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(height * 0.015),
        topRight: Radius.circular(height * 0.015),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading ?? const SizedBox.shrink(),
          const Spacer(),
          Text(
            title,
            style: MusicPlayerTheme.getTheme(
              context,
            ).textTheme.titleLarge!.copyWith(
              color: Colors.white,
              fontSize: height * 0.025,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IgnorePointer(
            ignoring: true,
            child: Opacity(
              opacity: 0,
              child: leading ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
