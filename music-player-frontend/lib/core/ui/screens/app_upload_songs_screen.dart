import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/ui/screens/upload_songs_screen.dart';

class AppUploadSongsScreen extends AbstractUploadSongsScreen {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return const AppUploadSongsScreen();
      },
    );
  }

  const AppUploadSongsScreen({super.key});

  @override
  State<AppUploadSongsScreen> createState() => _AppUploadSongsScreenState();
}

class _AppUploadSongsScreenState
    extends AbstractUploadSongsScreenState<AppUploadSongsScreen> {
  @override
  EdgeInsetsGeometry buildPadding(BuildContext context) {
    return const EdgeInsets.all(24);
  }
}