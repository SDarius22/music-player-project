import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/ui/screens/welcome_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/widgets/linux_top_bar_widget.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/library_settings.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/loading_screen.dart';

class WelcomeScreen extends AbstractWelcomeScreen {
  static Route<dynamic> route() {
    return MaterialPageRoute(builder: (_) => const WelcomeScreen());
  }

  const WelcomeScreen({super.key});

  @override
  AbstractWelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends AbstractWelcomeScreenState<WelcomeScreen> {
  @override
  PreferredSizeWidget buildAppBar(BuildContext context) {
    return const LinuxAppBarWidget();
  }

  @override
  EdgeInsetsGeometry buildPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: MediaQuery.of(context).size.height * 0.015,
      vertical: MediaQuery.of(context).size.height * 0.015,
    );
  }

  @override
  Widget buildBody(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    double boldSize = height * 0.035;
    return Column(
      children: [
        SizedBox(height: height * 0.25),
        Text(
          "Welcome to Music Player!",
          style: TextStyle(
            fontSize: boldSize,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: height * 0.025),
        LibrarySettings(backButton: false),
        SizedBox(height: height * 0.1),
        Container(
          width: width,
          padding: EdgeInsets.only(right: width * 0.075),
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(0),
              foregroundColor: Colors.white,
              backgroundColor: Colors.grey.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  MediaQuery.of(context).size.height * 0.015,
                ),
              ),
            ),
            onPressed:
                abstractAppStateProvider.appSettings.songPlaces.isEmpty
                    ? null
                    : () async {
                      debugPrint("Pressed");
                      abstractAppStateProvider.appSettings.firstTime = false;
                      debugPrint(
                        abstractAppStateProvider.appSettings.firstTime
                            .toString(),
                      );
                      abstractAppStateProvider.updateAppSettings();
                      Navigator.push(context, LoadingScreen.route());
                    },
            child: Icon(
              FluentIcons.forward,
              color: Colors.white,
              size: height * 0.03,
            ),
          ),
        ),
      ],
    );
  }
}
