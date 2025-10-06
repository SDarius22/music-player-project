import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/audio_player/abstract_audio_player.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/providers/lyrics_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/repository/queue_song_repo.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/theme.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/widgets/linux_top_bar_widget.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/home_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/welcome_screen.dart';
import 'package:provider/provider.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/loading'),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const LoadingScreen();
      },
    );
  }

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with AfterLayoutMixin<LoadingScreen> {
  @override
  void afterFirstLayout(BuildContext context) {
    _routeUser(context);
  }

  void _routeUser(BuildContext context) async {
    var abstractAppStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );
    if (abstractAppStateProvider.appSettings.firstTime ||
        abstractAppStateProvider.appSettings.mainSongPlace.isEmpty) {
      Navigator.pushReplacement(context, WelcomeScreen.route());
    } else {
      var audioProvider = Provider.of<AbstractAudioProvider>(
        context,
        listen: false,
      );
      await audioProvider.init(
        Provider.of<QueueSongRepository>(context, listen: false),
        Provider.of<SettingsService>(context, listen: false),
        Provider.of<SongService>(context, listen: false),
        Provider.of<AbstractAudioPlayer>(context, listen: false),
      );
      Provider.of<LyricsProvider>(context, listen: false);
      Provider.of<SongProvider>(
        context,
        listen: false,
      ).initialize(abstractAppStateProvider.appSettings.songPlaces);
      Navigator.pushReplacement(context, HomeScreen.route());
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: const AppBarWidget(),
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: MusicPlayerTheme.primaryGradient,
        ),
        child: const SafeArea(
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ),
    );
  }
}
