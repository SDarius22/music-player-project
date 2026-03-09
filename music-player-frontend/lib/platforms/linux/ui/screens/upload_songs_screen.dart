import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/ui/screens/upload_songs_screen.dart';

class LinuxUploadSongsScreen extends AbstractUploadSongsScreen {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return LinuxUploadSongsScreen();
      },
    );
  }

  const LinuxUploadSongsScreen({super.key});

  @override
  State<LinuxUploadSongsScreen> createState() => _LinuxUploadSongsScreenState();
}

class _LinuxUploadSongsScreenState
    extends AbstractUploadSongsScreenState<LinuxUploadSongsScreen> {
  @override
  EdgeInsetsGeometry buildPadding(BuildContext context) {
    return const EdgeInsets.all(24);
  }
}
