import 'package:flutter/material.dart';

/// Lyric UI base
/// All lyric UIs should extend this file
abstract class LyricUI {
  /// Main lyric style (playing line)
  TextStyle getPlayingMainTextStyle();

  /// Extended lyric style (playing line)
  TextStyle getPlayingExtTextStyle();

  /// Main lyric style (other lines)
  TextStyle getOtherMainTextStyle();

  /// Extended lyric style (other lines)
  TextStyle getOtherExtTextStyle();

  /// Default height for blank lines
  double getBlankLineHeight() => 0;

  /// Line spacing
  double getLineSpace();

  /// Inline spacing
  double getInlineSpace();

  /// Offset for the playing line
  /// Offset from top to bottom, range: 0~1;
  /// e.g.: 0.4
  double getPlayingLineBias();

  /// Ending looks ugly when it's smaller than half the size
  /// true: will at least offset to bias 0.5, won't be smaller than 0.5
  /// false: no limit, will offset to bias 0.5
  bool halfSizeLimit() => getPlayingLineBias() < 0.5;

  /// Lyric alignment direction
  /// Supports left, center, and right alignment
  LyricAlign getLyricHorizontalAlign();

  LyricBaseLine getBiasBaseLine() => LyricBaseLine.center;

  /// Centering method when a single line fills the width
  TextAlign getLyricTextAlign() {
    switch (getLyricHorizontalAlign()) {
      case LyricAlign.left:
        return TextAlign.left;
      case LyricAlign.right:
        return TextAlign.right;
      case LyricAlign.center:
        return TextAlign.center;
    }
  }

  /// Enable line animation
  bool enableLineAnimation() => true;

  bool enableHighlight() => true;

  // Init progress animation scroll to position
  bool initAnimation() => false;

  HighlightDirection getHighlightDirection() => HighlightDirection.leftToRight;

  Color getLyricHighlightColor() => Colors.amber;

  @override
  String toString() {
    return '${getPlayingMainTextStyle()}'
        '${getPlayingExtTextStyle()}'
        '${getOtherMainTextStyle()}'
        '${getOtherExtTextStyle()}'
        '${getBlankLineHeight()}'
        '${getLineSpace()}'
        '${getInlineSpace()}'
        '${getPlayingLineBias()}'
        '${getLyricHorizontalAlign()}'
        '${getLyricTextAlign()}'
        '${getBiasBaseLine()}';
  }
}

/// Lyric align enum
enum LyricAlign { left, center, right }

enum HighlightDirection { leftToRight, rightToLeft }

/// Lyric base line enum
enum LyricBaseLine { mainCenter, center, extCenter }
