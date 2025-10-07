import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/ui/components/animated_background.dart';
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
      Provider.of<SongProvider>(
        context,
        listen: false,
      ).initialize(abstractAppStateProvider.appSettings.songPlaces);
      Navigator.pushReplacement(context, HomeScreen.route());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(),
      body: SafeArea(
        child: AnimatedBackground(
          controller: AnimatedMeshGradientController(),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
