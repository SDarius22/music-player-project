import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/lyrics_provider.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:fluenticons/fluenticons.dart';
import 'package:lyric_reader/lyric_ui/lyric_ui.dart';
import 'package:lyric_reader/lyric_ui/ui_netease.dart';
import 'package:lyric_reader/lyrics_reader_widget.dart';
import 'package:multi_value_listenable_builder/mvlb.dart';
import 'package:provider/provider.dart';

class LyricsTab extends StatelessWidget {
  final bool oneLine;

  const LyricsTab({super.key, this.oneLine = false});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(aspectRatio: 1.0, child: _buildLyricsContent(context));
  }

  Widget _buildLyricsContent(BuildContext context) {
    var width = MediaQuery.of(context).size.width;

    UINetease lyricUI = UINetease(
      defaultTextStyle: MusicPlayerTheme.getTheme().textTheme.titleLarge!,
      defaultExtTextStyle: MusicPlayerTheme.getTheme().textTheme.titleMedium!
          .copyWith(color: oneLine ? Colors.transparent : Colors.grey),
      otherMainTextStyle: MusicPlayerTheme.getTheme().textTheme.titleMedium!
          .copyWith(color: oneLine ? Colors.transparent : Colors.grey),
      bias: 0.5,
      lineGap: 10,
      inlineGap: 25,
      lyricAlign: oneLine ? LyricAlign.center : LyricAlign.left,
      lyricBaseLine: LyricBaseLine.mainCenter,
      highlight: false,
    );
    var audioProvider = Provider.of<AudioProvider>(context, listen: false);
    var lyricsProvider = Provider.of<LyricsProvider>(context, listen: false);

    final lyrics = MultiValueListenableBuilder(
      valueListenables: [
        audioProvider.sliderNotifier,
        audioProvider.playingNotifier,
        lyricsProvider.loadingNotifier,
      ],
      builder: (context, values, child) {
        if (values[2]) {
          return const Center(
            child: Text(
              "Loading lyrics...",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          );
        }
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
                          audioProvider.seek(Duration(milliseconds: progress));
                        },
                      ),
                    );
                  },
          emptyBuilder:
              oneLine
                  ? null
                  : () {
                    return ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
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
                                MusicPlayerTheme.getTheme()
                                    .textTheme
                                    .bodyMedium,
                          ),
                        ),
                      ),
                    );
                  },
        );
      },
    );
    if (oneLine) return lyrics;
    return Stack(
      children: [
        Positioned.fill(child: lyrics),
        Positioned(
          top: 0,
          right: 0,
          child: PopupMenuButton<_LyricsAction>(
            tooltip: 'Lyrics options',
            icon: const Icon(FluentIcons.moreVertical, color: Colors.white70),
            onSelected: (action) => _handleAction(context, action),
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: _LyricsAction.incorrect,
                    child: ListTile(
                      leading: Icon(Icons.warning_amber_outlined),
                      title: Text('Mark lyrics as incorrect'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _LyricsAction.saveLocally,
                    child: ListTile(
                      leading: Icon(Icons.save_alt),
                      title: Text('Save locally'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _LyricsAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit lyrics'),
                    ),
                  ),
                ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(BuildContext context, _LyricsAction action) async {
    final provider = context.read<LyricsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _LyricsAction.incorrect:
        final replaced = await provider.markLyricsIncorrect();
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              replaced
                  ? 'Loaded another lyrics match'
                  : 'No alternative lyrics were found',
            ),
          ),
        );
        return;
      case _LyricsAction.saveLocally:
        final saved = await provider.saveLyricsLocally();
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              saved
                  ? 'Lyrics saved next to the song'
                  : 'This song does not have a writable local file',
            ),
          ),
        );
        return;
      case _LyricsAction.edit:
        await _editLyrics(context, provider);
        return;
    }
  }

  Future<void> _editLyrics(
    BuildContext context,
    LyricsProvider provider,
  ) async {
    final controller = TextEditingController(text: provider.unsyncedLyrics);
    final lyrics = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit lyrics'),
            content: SizedBox(
              width: 640,
              child: TextField(
                controller: controller,
                minLines: 12,
                maxLines: 24,
                decoration: const InputDecoration(
                  hintText: 'Paste synced or plain lyrics',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (lyrics == null || lyrics.trim().isEmpty || !context.mounted) return;
    final saved = await provider.updateLyrics(lyrics);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved ? 'Lyrics updated' : 'Could not update lyrics'),
      ),
    );
  }
}

enum _LyricsAction { incorrect, saveLocally, edit }
