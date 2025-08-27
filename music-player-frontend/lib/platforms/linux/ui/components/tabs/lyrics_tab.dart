import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/lyrics_provider.dart';
import 'package:music_player_frontend/core/ui/components/tabs/lyrics_tab.dart';
import 'package:music_player_frontend/platforms/linux/providers/audio_provider.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/font_scaler.dart';
import 'package:music_player_frontend/utils/lyric_reader/lyric_ui/lyric_ui.dart';
import 'package:music_player_frontend/utils/lyric_reader/lyric_ui/ui_netease.dart';
import 'package:music_player_frontend/utils/lyric_reader/lyrics_reader_widget.dart';
import 'package:music_player_frontend/utils/multivaluelistenablebuilder/mvlb.dart';
import 'package:provider/provider.dart';

class LyricsTab extends AbstractLyricsTab {
  const LyricsTab({super.key, super.oneLine = false});

  @override
  Widget buildLyricsContent(BuildContext context) {
    var width = MediaQuery.of(context).size.width;

    UINetease lyricUI = UINetease(
      defaultTextStyle: TextStyle(
        color: Colors.white,
        fontSize: LinuxFontScaler().scale(context, 22),
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.75),
            offset: const Offset(1, 2),
            blurRadius: 4,
          ),
        ],
      ),
      defaultExtTextStyle: TextStyle(
        color: oneLine ? Colors.transparent : Colors.grey,
        fontSize: LinuxFontScaler().scale(context, 20),
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: oneLine ? 0.0 : 0.75),
            offset: const Offset(1, 2),
            blurRadius: 4,
          ),
        ],
      ),
      otherMainTextStyle: TextStyle(
        color: oneLine ? Colors.transparent : Colors.grey,
        fontSize: LinuxFontScaler().scale(context, 20),
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: oneLine ? 0.0 : 0.5),
            offset: const Offset(1, 2),
            blurRadius: 4,
          ),
        ],
      ),
      bias: 0.5,
      lineGap: 5,
      inlineGap: 5,
      lyricAlign: LyricAlign.center,
      lyricBaseLine: LyricBaseLine.center,
      highlight: false,
    );
    var audioProvider = Provider.of<AudioProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: Colors.black,
        borderRadius: BorderRadius.circular(width * 0.025),
      ),
      child: Consumer<LyricsProvider>(
        builder: (_, lyricsProvider, __) {
          return MultiValueListenableBuilder(
            valueListenables: [
              audioProvider.sliderNotifier,
              audioProvider.playingNotifier,
            ],
            builder: (context, values, child) {
              return LyricsReader(
                model: lyricsProvider.lyricsModelBuilder,
                position: values[0],
                lyricUi: lyricUI,
                playing: values[1],
                size: Size.infinite,
                padding: EdgeInsets.only(
                  right: width * 0.01,
                  left: width * 0.01,
                ),
                selectLineBuilder:
                    oneLine
                        ? null
                        : (progress, confirm) {
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () async {
                                confirm.call();
                                audioProvider.seek(
                                  Duration(milliseconds: progress),
                                );
                              },
                            ),
                          );
                        },
                emptyBuilder:
                    oneLine
                        ? null
                        : () {
                          return lyricsProvider.unsyncedLyrics == ""
                              ? const Center(child: Text("No lyrics found"))
                              : ScrollConfiguration(
                                behavior: ScrollConfiguration.of(
                                  context,
                                ).copyWith(
                                  dragDevices: {
                                    PointerDeviceKind.touch,
                                    PointerDeviceKind.mouse,
                                  },
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  physics: const BouncingScrollPhysics(),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Text(lyricsProvider.unsyncedLyrics),
                                  ),
                                ),
                              );
                        },
              );
            },
          );
        },
      ),
    );
  }
}
