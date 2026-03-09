import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/song_rest_service.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:provider/provider.dart';

abstract class AbstractUploadSongsScreen extends StatefulWidget {
  const AbstractUploadSongsScreen({super.key});
}

abstract class AbstractUploadSongsScreenState<
  T extends AbstractUploadSongsScreen
>
    extends State<T> {
  final ValueNotifier<bool> isBusy = ValueNotifier<bool>(false);
  final List<Map<String, dynamic>> items = [];

  @override
  void dispose() {
    isBusy.dispose();
    super.dispose();
  }

  EdgeInsetsGeometry buildPadding(BuildContext context) => EdgeInsets.zero;

  PreferredSizeWidget buildAppBar(BuildContext context) {
    return AppBar(title: const Text('Upload songs to server'));
  }

  Widget buildHeader(BuildContext context) => const SizedBox.shrink();

  Widget buildEmptyState(BuildContext context) {
    return InkWell(
      onTap: pickSongs,
      child: const Center(
        child: Text(
          'Press here to pick songs to upload',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  void showToast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  FileService get fileService => context.read<FileService>();

  SongRestService get songRestService => context.read<SongRestService>();

  Future<void> pickSongs() async {
    if (isBusy.value) return;

    isBusy.value = true;
    try {
      final extensions = fileService.supportedAudioExtensions;

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: extensions,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final paths =
          result.files.map((f) => f.path).whereType<String>().toList();

      for (final path in paths) {
        if (!fileService.isSupportedAudioFile(path)) continue;

        try {
          final data = await fileService.retrieveSong(path, withImage: true);

          final alreadyAdded = items.any((e) => e['path'] == path);
          if (!alreadyAdded) {
            items.add(data);
          }
        } catch (_) {
          // ignore single-file failures
        }
      }

      if (mounted) setState(() {});
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> uploadAll() async {
    if (isBusy.value) return;
    if (items.isEmpty) return;

    isBusy.value = true;
    try {
      int okCount = 0;

      for (final item in items) {
        final ok = await songRestService.uploadFullSong(
          audioFilePath: item['path'],
          name: item['title'],
          artistName: item['artist'],
          albumName: item['album'],
          durationInSeconds: item['duration'],
          trackNumber: item['trackNumber'],
          discNumber: item['discNumber'],
          releaseYear: item['year'],
          coverArtBytes: item['image'],
        );

        if (ok) okCount += 1;
      }

      showToast('Uploaded $okCount/${items.length}');
    } finally {
      isBusy.value = false;
    }
  }

  Widget buildList(BuildContext context) {
    return ListView.separated(
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return InkWell(
            onTap: pickSongs,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 25),
              alignment: Alignment.center,
              child: const Text(
                'Add more songs',
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          );
        }

        final item = items[index];

        return ListTile(
          leading:
              (item['image'] != null && (item['image'] as dynamic).isNotEmpty)
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      item['image'],
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  )
                  : const SizedBox(width: 44, height: 44),
          title: Text(item['title'] ?? ''),
          subtitle: Text('${item['artist'] ?? ''} - ${item['album'] ?? ''}'),
          trailing: IconButton(
            onPressed: () => setState(() => items.removeAt(index)),
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: buildAppBar(context),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: isBusy,
        builder: (context, busy, _) {
          if (items.isEmpty) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: busy ? null : uploadAll,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Upload'),
          );
        },
      ),
      body: Padding(
        padding: buildPadding(context),
        child: Column(
          children: [
            buildHeader(context),
            Expanded(
              child:
                  items.isEmpty ? buildEmptyState(context) : buildList(context),
            ),
          ],
        ),
      ),
    );
  }
}
