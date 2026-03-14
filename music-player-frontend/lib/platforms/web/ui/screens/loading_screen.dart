import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/ui/screens/loading_screen.dart';
import 'package:music_player_frontend/platforms/web/ui/screens/main_scaffold.dart';
import 'package:music_player_frontend/platforms/web/ui/screens/welcome_screen.dart';
import 'package:provider/provider.dart';

class LoadingScreen extends AbstractLoadingScreen {
  const LoadingScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return const LoadingScreen();
      },
    );
  }

  @override
  LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends LoadingScreenState<LoadingScreen>
    with AfterLayoutMixin<LoadingScreen> {
  @override
  void routeUser(BuildContext context) async {
    final userProvider = context.read<UserProvider>();

    // Try refreshing tokens if present.
    final ok = await userProvider.tryAutoLogin();
    if (!context.mounted) return;

    if (!ok) {
      Navigator.pushReplacement(context, WelcomeScreen.route());
      return;
    }

    final SongProvider songProvider = context.read<SongProvider>();
    songProvider.preferServer = true;
    songProvider.fallbackToServer = true;
    songProvider.refreshSongs();
    Navigator.pushReplacement(context, WebMainScaffold.route());
  }
}
