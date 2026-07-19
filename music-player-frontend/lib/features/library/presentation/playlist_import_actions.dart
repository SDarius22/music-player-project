import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/features/library/application/playlist_file_gateway.dart';
import 'package:music_player_frontend/features/library/application/playlist_transfer_service.dart';
import 'package:music_player_frontend/features/library/presentation/screens/create_or_import_screen.dart';
import 'package:provider/provider.dart';

class PlaylistImportActions {
  const PlaylistImportActions._();

  static Future<void> importPlaylist(BuildContext context) async {
    final file = await context.read<PlaylistFileGateway>().pickPlaylist();
    if (file == null || !context.mounted) return;
    final result = await context.read<PlaylistTransferService>().importPlaylist(
      bytes: file.bytes,
      sourceName: file.name,
      sourcePath: file.path,
    );
    if (!context.mounted) return;
    if (result.songs.isEmpty) {
      _toast('No songs from this playlist could be matched');
      return;
    }
    if (result.unresolvedEntries.isNotEmpty) {
      _toast(
        'Matched ${result.songs.length} songs; '
        '${result.unresolvedEntries.length} could not be found',
      );
    }
    context
        .read<AbstractAppStateProvider>()
        .innerNavigatorKey
        .currentState
        ?.push(
          CreateOrImportScreen.route(
            playlistName: result.playlistName,
            initialSongs: result.songs,
            import: true,
          ),
        );
  }

  static void _toast(String message) {
    BotToast.showText(text: message, duration: const Duration(seconds: 3));
  }
}
