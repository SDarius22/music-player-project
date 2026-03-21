import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/song_rest_service.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:provider/provider.dart';

class UploadSongsScreen extends StatefulWidget {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: "/upload-songs"),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const UploadSongsScreen();
      },
    );
  }

  const UploadSongsScreen({super.key});

  @override
  State<UploadSongsScreen> createState() => _UploadSongsScreenState();
}

class _UploadSongsScreenState extends State<UploadSongsScreen> {
  final ValueNotifier<bool> isBusy = ValueNotifier<bool>(false);
  final List<Map<String, dynamic>> items = [];

  @override
  void dispose() {
    isBusy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
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
        child: items.isEmpty ? buildEmptyState(context) : buildList(context),
      ),
    );
  }

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

  AbstractFileService get fileService => context.read<AbstractFileService>();

  SongRestService get songRestService => context.read<SongRestService>();

  Future<void> pickSongs() async {
    if (isBusy.value) return;

    final selectionType = await showDialog<String>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('Select Source'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'files'),
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('Pick specific files'),
                ),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'dir'),
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('Pick a folder'),
                ),
              ),
            ],
          ),
    );

    if (selectionType == null) return;

    isBusy.value = true;
    try {
      final List<String> paths = [];
      final extensions = fileService.supportedAudioExtensions;

      if (selectionType == 'dir') {
        final dirPath = await FilePicker.platform.getDirectoryPath();
        if (dirPath != null) {
          final dir = Directory(dirPath);
          if (await dir.exists()) {
            await for (final entity in dir.list(
              recursive: true,
              followLinks: false,
            )) {
              if (entity is File) {
                paths.add(entity.path);
              }
            }
          }
        }
      } else {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: extensions,
          withData: false,
        );

        if (result != null) {
          paths.addAll(result.files.map((f) => f.path).whereType<String>());
        }
      }

      if (paths.isEmpty) return;

      for (final path in paths) {
        if (!fileService.isSupportedAudioFile(path)) continue;

        if (items.any((e) => e['path'] == path)) continue;

        try {
          final data = await fileService.retrieveSong(path, withImage: true);

          data['progress'] = 0.0;
          data['uploading'] = false;
          items.add(data);

          if (items.length % 10 == 0 && mounted) setState(() {});
        } catch (_) {
          // ignore single-file parsing failures
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

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        setState(() {
          item['uploading'] = true;
          item['progress'] = 0.0;
        });

        try {
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
            onProgress: (sent, total) {
              if (!mounted) return;
              final p = total == 0 ? 0.0 : (sent / total).clamp(0.0, 1.0);
              setState(() => item['progress'] = p);
            },
          );
          setState(() => item['uploading'] = false);
          if (ok) okCount += 1;
        } catch (_) {
          setState(() {
            item['uploading'] = false;
            item['progress'] = 0.0;
          });
        }
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
        final progress = (item['progress'] as double?) ?? 0.0;
        final uploading = (item['uploading'] as bool?) ?? false;

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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item['artist'] ?? ''} - ${item['album'] ?? ''}'),
              if (uploading || progress >= 0.1) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 4),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
              ],
            ],
          ),
          trailing: IconButton(
            onPressed:
                uploading ? null : () => setState(() => items.removeAt(index)),
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
          ),
        );
      },
    );
  }

  EdgeInsetsGeometry buildPadding(BuildContext context) {
    return const EdgeInsets.all(24);
  }
}
