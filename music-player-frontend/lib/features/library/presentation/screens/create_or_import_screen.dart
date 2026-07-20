import 'package:bot_toast/bot_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/features/library/application/playlist_transfer_service.dart';
import 'package:music_player_frontend/features/library/presentation/providers/playlist_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/song_provider.dart';
import 'package:music_player_frontend/shared/presentation/tiling/paginated_component.dart';
import 'package:music_player_frontend/shared/presentation/tiling/tile_type.dart';
import 'package:music_player_frontend/shared/presentation/widgets/entity_cover.dart';
import 'package:music_player_frontend/features/library/presentation/screens/base/entity_screen.dart';
import 'package:fluenticons/fluenticons.dart';
import 'package:glass_kit/glass_container.dart';
import 'package:multi_value_listenable_builder/mvlb.dart';
import 'package:provider/provider.dart';
import 'package:universal_platform/universal_platform.dart';

import 'package:music_player_frontend/shared/presentation/navigation/route_builder.dart';

class CreateOrImportScreen extends EntityScreen<SongProvider> {
  static Route<void> route({
    String playlistName = "",
    List<String> songFileHashes = const [],
    List<Song> initialSongs = const [],
    bool import = false,
    PlaylistImportRequest? importRequest,
  }) {
    final draftPlaylist = Playlist(playlistName);
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => CreateOrImportScreen(
        entity: draftPlaylist,
        provider: context.read<SongProvider>(),
        songFileHashes: songFileHashes,
        initialSongs: initialSongs,
        import: import,
        importRequest: importRequest,
      ),
      settings: RouteSettings(name: import ? "/import" : "/create"),
    );
  }

  final List<String> songFileHashes;
  final List<Song> initialSongs;
  final bool import;
  final PlaylistImportRequest? importRequest;

  final ValueNotifier<List<Song>> selected = ValueNotifier<List<Song>>([]);
  final ValueNotifier<Uint8List?> coverArt = ValueNotifier<Uint8List?>(null);
  final ValueNotifier<int> reloadToken = ValueNotifier<int>(0);
  final ValueNotifier<bool> _initialized = ValueNotifier<bool>(false);
  final ValueNotifier<String> search = ValueNotifier<String>("");
  final ValueNotifier<String> playlistName;

  CreateOrImportScreen({
    super.key,
    required Playlist super.entity,
    required super.provider,
    required this.songFileHashes,
    this.initialSongs = const [],
    required this.import,
    this.importRequest,
  }) : playlistName = ValueNotifier<String>(entity.name);

  @override
  Future<BaseEntity> loadEntityData(BuildContext context) async {
    if (_initialized.value) {
      return entity;
    }
    _initialized.value = true;

    if (importRequest != null) {
      await _runImport(context, importRequest!);
      reloadToken.value++;
      return entity;
    }

    if (initialSongs.isNotEmpty) {
      selected.value = List<Song>.from(initialSongs);
      if (coverArt.value == null) {
        coverArt.value = initialSongs.first.getCoverArt();
      }
      reloadToken.value++;
      return entity;
    }

    if (songFileHashes.isEmpty) {
      reloadToken.value++;
      return entity;
    }

    final songProvider = context.read<SongProvider>();
    final songs = <Song>[];

    for (final hash in songFileHashes) {
      final song = await songProvider.fetchEntity(Song(hash));
      if (song != null) {
        songs.add(song);
      }
    }

    selected.value = songs;
    if (songs.isNotEmpty && coverArt.value == null) {
      coverArt.value = songs.first.getCoverArt();
    }

    reloadToken.value++;
    return entity;
  }

  @override
  PreferredSizeWidget buildAppBar(BuildContext context, BaseEntity entity) {
    final width = MediaQuery.of(context).size.width;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        height: kToolbarHeight,
        padding: EdgeInsets.symmetric(horizontal: width * 0.01),
        margin: EdgeInsets.symmetric(vertical: width * 0.005),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(FluentIcons.back, size: 20, color: Colors.white),
            ),
            Text(
              import ? "Import a playlist" : "Create a new playlist",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Spacer(),
            SizedBox(
              width: width * 0.08,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.01),
                ),
                onPressed: () async => _handleCreatePlaylist(context),
                child: Text(
                  "Done",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildDetailsSection(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    final imageSize = constraints.maxWidth * 0.35;
    final borderRadius = BorderRadius.circular(constraints.maxHeight * 0.015);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.05),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: imageSize,
            width: imageSize,
            padding: EdgeInsets.only(bottom: constraints.maxHeight * 0.01),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: MultiValueListenableBuilder(
                valueListenables: [coverArt, selected],
                builder: (context, values, child) {
                  final selectedCover = values[0] as Uint8List?;
                  final selectedSongs = values[1] as List<Song>;

                  if (selectedCover != null) {
                    final customCoverPlaylist = Playlist('');
                    customCoverPlaylist.imageBytes = selectedCover;
                    return EntityCover(
                      entity: customCoverPlaylist,
                      hoveredChild: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () => _pickCoverArt(context),
                            icon: const Icon(
                              FluentIcons.camera,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                          IconButton(
                            onPressed: () => coverArt.value = null,
                            icon: const Icon(
                              FluentIcons.trash,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return EntityCover(
                    entity:
                        selectedSongs.isNotEmpty
                            ? selectedSongs.first
                            : Song(''),
                    hoveredChild: IconButton(
                      onPressed: () => _pickCoverArt(context),
                      icon: const Icon(
                        FluentIcons.camera,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          TextFormField(
            maxLength: 50,
            initialValue: playlistName.value,
            decoration: InputDecoration(
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              hintText: 'Playlist name',
              counterText: "",
              hintStyle: Theme.of(
                context,
              ).textTheme.bodySmall!.copyWith(color: Colors.grey),
            ),
            cursorColor: Colors.white,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(color: Colors.white),
            onChanged: (value) => playlistName.value = value,
          ),
        ],
      ),
    );
  }

  @override
  Widget buildContentSection(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final margin = EdgeInsets.symmetric(
      vertical: height * 0.01,
      horizontal: width * 0.02,
    );
    final borderRadius = BorderRadius.circular(height * 0.015);

    return GlassContainer(
      margin: margin,
      color: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      borderRadius: borderRadius,
      blur: 45.0,
      borderWidth: 0.0,
      elevation: 3.0,
      shadowColor: Colors.black.withValues(alpha: 0.20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.only(
              top: height * 0.02,
              left: width * 0.01,
              right: width * 0.01,
            ),
            child: TextFormField(
              onChanged: (value) {
                search.value = value;
                reloadToken.value++;
              },
              cursorColor: Colors.white,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: Colors.white),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(height * 0.015),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                labelStyle: Theme.of(
                  context,
                ).textTheme.bodySmall!.copyWith(color: Colors.white),
                labelText: 'Search',
                suffixIcon: const Icon(
                  FluentIcons.search,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<Song>>(
              valueListenable: selected,
              builder: (context, selectedSongs, child) {
                return ValueListenableBuilder<int>(
                  valueListenable: reloadToken,
                  builder: (context, token, _) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: height * 0.01,
                        horizontal: width * 0.01,
                      ),
                      child: PaginatedComponent(
                        type: TileType.list,
                        reloadToken: token,
                        pageSize: 30,
                        itemExtent: height * 0.1,
                        emptyText: 'No songs found',
                        onRefresh: () {
                          final songProvider = context.read<SongProvider>();
                          return songProvider.refresh();
                        },
                        fetchPage: (page, size) {
                          final songProvider = context.read<SongProvider>();
                          return songProvider.fetchPage(
                            search.value,
                            'Title',
                            true,
                            false,
                            page,
                            size,
                          );
                        },
                        isSelected:
                            (songEntity) =>
                                selectedSongs.contains(songEntity as Song),
                        onTap: (songEntity, items) async {
                          final song = songEntity as Song;
                          if (selected.value.contains(song)) {
                            selected.value = List.from(selected.value)
                              ..remove(song);
                          } else {
                            selected.value = List.from(selected.value)
                              ..add(song);
                          }
                        },
                        onLongPress: (songEntity, items) {},
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runImport(
    BuildContext context,
    PlaylistImportRequest request,
  ) async {
    final service = context.read<PlaylistTransferService>();
    final PlaylistImportResult result;
    try {
      result = await service.importPlaylist(
        bytes: request.bytes,
        sourceName: request.sourceName,
        sourcePath: request.sourcePath,
      );
    } catch (_) {
      _showToast('Could not read ${request.sourceName} as an M3U playlist');
      return;
    }

    playlistName.value = result.playlistName;
    selected.value = List<Song>.from(result.songs);
    if (result.songs.isNotEmpty) {
      coverArt.value ??= result.songs.first.getCoverArt();
    }

    if (result.songs.isEmpty) {
      _showToast('No songs from this playlist could be matched');
    } else if (result.unresolvedEntries.isNotEmpty) {
      _showToast(
        'Matched ${result.songs.length} songs; '
        '${result.unresolvedEntries.length} could not be found',
      );
    }
  }

  Future<void> _handleCreatePlaylist(BuildContext context) async {
    if (playlistName.value.trim().isEmpty) {
      _showToast("Playlist name cannot be empty");
      return;
    }
    if (selected.value.isEmpty) {
      _showToast("You must select at least one song");
      return;
    }

    final playlistProvider = context.read<PlaylistProvider>();
    await playlistProvider.addPlaylist(
      playlistName.value.trim(),
      selected.value,
      coverArt.value,
    );

    if (!context.mounted) return;

    _showToast(
      import
          ? "Playlist imported successfully"
          : "Playlist created successfully",
    );
    Navigator.pop(context);
  }

  Future<void> _pickCoverArt(BuildContext context) async {
    final appState = context.read<AbstractAppStateProvider>();

    final result = await FilePicker.platform.pickFiles(
      initialDirectory:
          UniversalPlatform.isWeb ? null : appState.appSettings.mainSongPlace,
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final bytes = result.files.single.bytes;
    if (bytes != null) {
      coverArt.value = bytes;
    }
  }

  void _showToast(String message, {int durationSeconds = 3}) {
    BotToast.showText(
      text: message,
      duration: Duration(seconds: durationSeconds),
    );
  }
}
