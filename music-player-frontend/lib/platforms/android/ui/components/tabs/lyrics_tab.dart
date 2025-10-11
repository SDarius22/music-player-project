import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/providers/lyrics_provider.dart';
import 'package:music_player_frontend/core/ui/components/tabs/lyrics_tab.dart';
import 'package:music_player_frontend/local_libs/lyric_reader/lyric_ui/lyric_ui.dart';
import 'package:music_player_frontend/local_libs/lyric_reader/lyric_ui/ui_netease.dart';
import 'package:music_player_frontend/local_libs/lyric_reader/lyrics_reader_widget.dart';
import 'package:music_player_frontend/local_libs/multivaluelistenablebuilder/mvlb.dart';
import 'package:music_player_frontend/platforms/android/ui/components/theme.dart';
import 'package:provider/provider.dart';

class LyricsTab extends AbstractLyricsTab {
  const LyricsTab({super.key, super.oneLine = false});

  @override
  Widget buildLyricsContent(BuildContext context) {
    var width = MediaQuery.of(context).size.width;

    UINetease lyricUI = UINetease(
      defaultTextStyle: MusicPlayerTheme.getTheme(
        context,
      ).textTheme.headlineLarge!.copyWith(
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.75),
            offset: const Offset(1, 2),
            blurRadius: 4,
          ),
        ],
      ),
      defaultExtTextStyle: MusicPlayerTheme.getTheme(
        context,
      ).textTheme.headlineMedium!.copyWith(
        color: oneLine ? Colors.transparent : Colors.grey,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: oneLine ? 0.0 : 0.75),
            offset: const Offset(1, 2),
            blurRadius: 4,
          ),
        ],
      ),
      otherMainTextStyle: MusicPlayerTheme.getTheme(
        context,
      ).textTheme.headlineMedium!.copyWith(
        color: oneLine ? Colors.transparent : Colors.grey,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: oneLine ? 0.0 : 0.5),
            offset: const Offset(1, 2),
            blurRadius: 4,
          ),
        ],
      ),
      bias: 0.5,
      lineGap: 10,
      inlineGap: 25,
      lyricAlign: LyricAlign.center,
      lyricBaseLine: LyricBaseLine.mainCenter,
      highlight: false,
    );
    var audioProvider = Provider.of<AbstractAudioProvider>(
      context,
      listen: false,
    );

    return Consumer<LyricsProvider>(
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
              padding: EdgeInsets.only(left: width * 0.01),
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
                                  child: Text(
                                    lyricsProvider.unsyncedLyrics,
                                    style:
                                        MusicPlayerTheme.getTheme(
                                          context,
                                        ).textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                            );
                      },
            );
          },
        );
      },
    );
  }
}
