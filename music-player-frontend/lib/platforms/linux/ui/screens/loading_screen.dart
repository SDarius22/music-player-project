import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:musicplayer/providers/app_state_provider.dart';
import 'package:musicplayer/providers/audio_provider.dart';
import 'package:musicplayer/providers/lyrics_provider.dart';
import 'package:musicplayer/providers/song_provider.dart';
import 'package:musicplayer/screens/home_screen.dart';
import 'package:musicplayer/screens/welcome_screen.dart';
import 'package:musicplayer/services/settings_service.dart';
import 'package:musicplayer/services/song_service.dart';
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

class _LoadingScreenState extends State<LoadingScreen> with AfterLayoutMixin<LoadingScreen> {
  @override
  void afterFirstLayout(BuildContext context) {
    _routeUser(context);
  }

  void _routeUser(BuildContext context) async {
    // var infoProvider = Provider.of<InfoProvider>(context, listen: false);
    var appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
    if (appStateProvider.appSettings.firstTime || appStateProvider.appSettings.mainSongPlace.isEmpty) {
      Navigator.pushReplacement(context, WelcomeScreen.route());
    }
    else {
      var audioProvider = Provider.of<AudioProvider>(context, listen: false);
      await audioProvider.init(Provider.of<SettingsService>(context, listen: false), Provider.of<SongService>(context, listen: false));
      Provider.of<LyricsProvider>(context, listen: false).init(audioProvider);
      Provider.of<SongProvider>(context, listen: false).startLoadingSongs();
      Navigator.pushReplacement(context, HomeScreen.route());
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}