import 'package:flutter/material.dart';
import 'lyric_ui.dart';

///Sample Netease style
///should be extends LyricUI implementation your own UI.
///this property only for change UI,if not demand just only overwrite methods.
class UINetease extends LyricUI {
  TextStyle defaultTextStyle;
  TextStyle defaultExtTextStyle;
  TextStyle otherMainTextStyle;

  double bias;
  double lineGap;
  double inlineGap;
  LyricAlign lyricAlign;
  LyricBaseLine lyricBaseLine;
  bool highlight;
  HighlightDirection highlightDirection;
  Color highlightColor;

  UINetease(
      {this.defaultTextStyle = const TextStyle(color: Colors.white, fontSize: 20),
      this.defaultExtTextStyle = const TextStyle(color: Colors.grey, fontSize: 16),
      this.otherMainTextStyle = const TextStyle(color: Colors.grey, fontSize: 20),
      this.bias = 0.5,
      this.lineGap = 25,
      this.inlineGap = 25,
      this.lyricAlign = LyricAlign.center,
      this.lyricBaseLine = LyricBaseLine.center,
      this.highlightColor = Colors.blue,
      this.highlight = true,
      this.highlightDirection = HighlightDirection.leftToRight});

  UINetease.clone(UINetease uiNetease)
      : this(
          defaultTextStyle: uiNetease.defaultTextStyle,
          defaultExtTextStyle: uiNetease.defaultExtTextStyle,
          otherMainTextStyle: uiNetease.otherMainTextStyle,
          bias: uiNetease.bias,
          lineGap: uiNetease.lineGap,
          inlineGap: uiNetease.inlineGap,
          lyricAlign: uiNetease.lyricAlign,
          lyricBaseLine: uiNetease.lyricBaseLine,
          highlightColor: uiNetease.highlightColor,
          highlight: uiNetease.highlight,
          highlightDirection: uiNetease.highlightDirection,
        );

  @override
  TextStyle getPlayingExtTextStyle() => defaultExtTextStyle;

  @override
  TextStyle getOtherExtTextStyle() => defaultExtTextStyle;

  @override
  TextStyle getOtherMainTextStyle() => otherMainTextStyle;

  @override
  TextStyle getPlayingMainTextStyle() => defaultTextStyle;

  @override
  double getInlineSpace() => inlineGap;

  @override
  double getLineSpace() => lineGap;

  @override
  double getPlayingLineBias() => bias;

  @override
  LyricAlign getLyricHorizontalAlign() => lyricAlign;

  @override
  LyricBaseLine getBiasBaseLine() => lyricBaseLine;

  @override
  bool enableHighlight() => highlight;

  @override
  HighlightDirection getHighlightDirection() => highlightDirection;
}
