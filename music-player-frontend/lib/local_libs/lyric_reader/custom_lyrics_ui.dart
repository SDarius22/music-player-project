import 'package:music_player_frontend/local_libs/lyric_reader/lyric_ui/ui_netease.dart';

class CustomLyricUI extends UINetease {
  final double playingLineGap;
  final double otherLineGap;

  CustomLyricUI({
    required super.defaultTextStyle,
    required super.defaultExtTextStyle,
    required super.otherMainTextStyle,
    super.bias,
    super.inlineGap,
    super.lyricAlign,
    super.lyricBaseLine,
    super.highlight,
    this.playingLineGap = 25.0, // Spacing for the currently playing line
    this.otherLineGap = 5.0, // Spacing for other lines
  });

  @override
  double getLineSpace() {
    // Return different spacing for the playing line
    return isPlayingLine ? playingLineGap : otherLineGap;
  }

  // Add a flag to determine if the line is the currently playing line
  bool isPlayingLine = false;

  void setPlayingLine(bool isPlaying) {
    isPlayingLine = isPlaying;
  }
}
