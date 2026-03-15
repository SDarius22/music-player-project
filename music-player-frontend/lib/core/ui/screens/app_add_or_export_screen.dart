import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class AppAddOrExportScreen extends AbstractAddOrExportScreen {
  static Route route({List<Song> songs = const [], bool export = false}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return AppAddOrExportScreen(songs: songs, export: export);
      },
    );
  }

  const AppAddOrExportScreen({super.key, super.songs, super.export});

  @override
  State<AppAddOrExportScreen> createState() => _AppAddOrExportScreenState();
}

class _AppAddOrExportScreenState
    extends AbstractAddOrExportScreenState<AppAddOrExportScreen> {
  @override
  Widget buildHeader(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            debugPrint("Back");
            Navigator.pop(context);
          },
          icon: Icon(
            FluentIcons.back,
            size: height * 0.02,
            color: Colors.white,
          ),
        ),
        SizedBox(width: width * 0.01),
        Text(
          "Choose one or more playlists to ${widget.export ? 'export' : 'add to'}",
          style: MusicPlayerTheme.getTheme(
            context,
            context.read<Scaler>(),
          ).textTheme.headlineMedium,
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: () {
            if (selected.value.isEmpty) {
              BotToast.showText(text: "Please select at least one playlist");
              return;
            }
            if (widget.export) {
              var abstractAppStateProvider =
                  Provider.of<AbstractAppStateProvider>(context, listen: false);
              for (int i = 0; i < selected.value.length; i++) {
                Playlist playlist = selected.value[i];
                var songPaths = playlist.songsList.map((e) => e.path).toList();
                var fileName =
                    "${abstractAppStateProvider.appSettings.mainSongPlace}/${playlist.name}.m3u";
                final fileService = Provider.of<AbstractFileService>(
                  context,
                  listen: false,
                );
                fileService.exportPlaylist(fileName, songPaths);
              }
            }
            for (int i = 0; i < selected.value.length; i++) {
              Playlist playlist = selected.value[i];
              if (playlist.indestructible && playlist.name == 'Current Queue') {
                var audioProvider = Provider.of<AudioProvider>(
                  context,
                  listen: false,
                );
                audioProvider.addLastToQueue(widget.songs);
              } else {
                var playlistProvider = Provider.of<PlaylistProvider>(
                  context,
                  listen: false,
                );
                playlistProvider.addSongsToPlaylist(playlist, widget.songs);
              }
            }
            Navigator.pop(context);
          },
          child: Text(
            "Done",
            style: MusicPlayerTheme.getTheme(
              context,
              context.read<Scaler>(),
            ).textTheme.headlineMedium,
          ),
        ),
      ],
    );
  }
}