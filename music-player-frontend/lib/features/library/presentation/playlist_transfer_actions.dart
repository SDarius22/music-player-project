import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/services/entity_song_order.dart';
import 'package:music_player_frontend/features/library/application/playlist_file_gateway.dart';
import 'package:music_player_frontend/features/library/application/playlist_transfer_service.dart';
import 'package:music_player_frontend/features/library/domain/m3u_playlist.dart';
import 'package:music_player_frontend/features/library/presentation/providers/playlist_provider.dart';
import 'package:provider/provider.dart';

class PlaylistTransferActions {
  const PlaylistTransferActions._();

  static Future<M3uExportMode?> chooseExportMode(BuildContext context) {
    return showDialog<M3uExportMode>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Export format'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in M3uExportMode.values)
                  ListTile(
                    title: Text(mode.label),
                    subtitle: Text(mode.description),
                    onTap: () => Navigator.of(dialogContext).pop(mode),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  static Future<bool> exportPlaylist(
    BuildContext context,
    Playlist playlist, {
    M3uExportMode? mode,
  }) async {
    final selectedMode = mode ?? await chooseExportMode(context);
    if (selectedMode == null || !context.mounted) return false;
    final provider = context.read<PlaylistProvider>();
    final songs = await EntitySongOrder.load(playlist, provider);
    if (!context.mounted) return false;
    final result = context.read<PlaylistTransferService>().exportPlaylist(
      playlist,
      songs,
      selectedMode,
    );
    final saved = await context.read<PlaylistFileGateway>().savePlaylist(
      fileName: result.fileName,
      bytes: result.bytes,
    );
    if (!saved) return false;
    final skipped = result.skippedSongs.length;
    _toast(
      skipped == 0
          ? 'Exported ${playlist.name}'
          : 'Exported ${result.exportedSongs} songs; skipped $skipped '
              'without local files',
    );
    return true;
  }

  static void _toast(String message) {
    BotToast.showText(text: message, duration: const Duration(seconds: 3));
  }
}
