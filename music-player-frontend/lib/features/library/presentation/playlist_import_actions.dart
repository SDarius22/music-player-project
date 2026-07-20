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

    context.read<AbstractAppStateProvider>().innerNavigatorKey.currentState
        ?.push(
          CreateOrImportScreen.route(
            import: true,
            importRequest: PlaylistImportRequest(
              bytes: file.bytes,
              sourceName: file.name,
              sourcePath: file.path,
            ),
          ),
        );
  }
}
