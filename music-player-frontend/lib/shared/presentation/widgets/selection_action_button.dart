import 'package:flutter/material.dart';
import 'package:fluenticons/fluenticons.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/queryable_provider.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/selection_provider.dart';
import 'package:music_player_frontend/core/services/entity_song_order.dart';
import 'package:music_player_frontend/features/library/presentation/screens/add_or_export_screen.dart';
import 'package:provider/provider.dart';

enum _SelectionAction { play, playNext, addTo, download, cancel }

class SelectionActionButton extends StatefulWidget {
  const SelectionActionButton({
    super.key,
    required this.provider,
    required this.selected,
  });

  final QueryableProvider provider;
  final Set<BaseEntity> selected;

  @override
  State<SelectionActionButton> createState() => _SelectionActionButtonState();
}

class _SelectionActionButtonState extends State<SelectionActionButton> {
  late Future<List<Song>> _songs;

  @override
  void initState() {
    super.initState();
    _songs = _resolveSongs();
  }

  @override
  void didUpdateWidget(covariant SelectionActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameSelection(oldWidget.selected, widget.selected)) {
      _songs = _resolveSongs();
    }
  }

  bool _sameSelection(Set<BaseEntity> a, Set<BaseEntity> b) =>
      a.length == b.length && a.containsAll(b);

  Future<List<Song>> _resolveSongs() async {
    final songs = <String, Song>{};
    for (final entity in widget.selected) {
      for (final song in await EntitySongOrder.load(entity, widget.provider)) {
        songs.putIfAbsent(song.getHash(), () => song);
      }
    }
    return songs.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Song>>(
      future: _songs,
      builder: (context, snapshot) {
        final songs = snapshot.data ?? const <Song>[];
        final loading = snapshot.connectionState != ConnectionState.done;
        final label =
            loading ? 'Loading selection…' : '${songs.length} songs selected';
        return FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon(FluentIcons.check),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 8),
              PopupMenuButton<_SelectionAction>(
                tooltip: 'Selection actions',
                enabled: !loading,
                icon: const Icon(FluentIcons.moreVertical),
                onSelected: (action) => _handleAction(action, songs),
                itemBuilder:
                    (context) => const [
                      PopupMenuItem(
                        value: _SelectionAction.play,
                        child: Text('Play'),
                      ),
                      PopupMenuItem(
                        value: _SelectionAction.playNext,
                        child: Text('Play Next'),
                      ),
                      PopupMenuItem(
                        value: _SelectionAction.addTo,
                        child: Text('Add to'),
                      ),
                      PopupMenuItem(
                        value: _SelectionAction.download,
                        child: Text('Download'),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: _SelectionAction.cancel,
                        child: Text('Cancel'),
                      ),
                    ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleAction(_SelectionAction action, List<Song> songs) async {
    if (!mounted) return;
    final selection = context.read<SelectionProvider>();
    switch (action) {
      case _SelectionAction.play:
        if (songs.isNotEmpty) {
          await context.read<AudioProvider>().setQueueAndPlay(
            songs,
            songs.first,
          );
        }
      case _SelectionAction.playNext:
        if (songs.isNotEmpty) {
          await context.read<AudioProvider>().addNextToQueue(songs);
        }
      case _SelectionAction.addTo:
        if (songs.isNotEmpty) {
          context
              .read<AbstractAppStateProvider>()
              .innerNavigatorKey
              .currentState
              ?.push(AddOrExportScreen.route(songs: songs));
        }
      case _SelectionAction.download:
        await _download(songs);
      case _SelectionAction.cancel:
        selection.clearSelection();
    }
  }

  Future<void> _download(List<Song> songs) async {
    final downloadable = songs
        .where((song) => song.isAvailableToStream && !song.isAvailableOffline)
        .toList(growable: false);
    final messenger = ScaffoldMessenger.of(context);
    final audioProvider = context.read<AudioProvider>();
    if (downloadable.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Selected songs are already offline')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Downloading ${downloadable.length} songs…')),
    );
    var completed = 0;
    for (final song in downloadable) {
      try {
        await audioProvider.downloadSong(song);
        completed++;
      } catch (_) {
        // Continue downloading the remaining selected songs.
      }
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Downloaded $completed of ${downloadable.length} songs'),
      ),
    );
  }
}
