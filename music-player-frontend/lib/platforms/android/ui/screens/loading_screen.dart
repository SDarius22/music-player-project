import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/animated_background.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_top_bar_widget.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/home_screen.dart';
import 'package:provider/provider.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder(
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
    await Provider.of<SongProvider>(context, listen: false).initialize([]);
    if (context.mounted) {
      Navigator.pushReplacement(context, HomeScreen.route());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: "Music Player"),
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
