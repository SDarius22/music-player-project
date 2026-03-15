import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/screens/app_loading_screen.dart';
import 'package:music_player_frontend/core/ui/screens/welcome_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/library_settings.dart';
import 'package:provider/provider.dart';

class AppWelcomeScreen extends AbstractWelcomeScreen {
  static Route<dynamic> route() {
    return MaterialPageRoute(builder: (_) => const AppWelcomeScreen());
  }

  const AppWelcomeScreen({super.key});

  @override
  AbstractWelcomeScreenState createState() => _AppWelcomeScreenState();
}

class _AppWelcomeScreenState
    extends AbstractWelcomeScreenState<AppWelcomeScreen> {
  @override
  PreferredSizeWidget buildAppBar(BuildContext context) {
    return const PreferredSize(
      preferredSize: Size.fromHeight(0),
      child: SizedBox.shrink(),
    );
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
    return Consumer<AbstractAppStateProvider>(
      builder: (context, appState, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Welcome to Music Player!",
              style: TextStyle(
                fontSize: boldSize,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: height * 0.025),
            SizedBox(
              width: width * 0.75,
              height: height * 0.5,
              child: LibrarySettings(
                abstractAppStateProvider: appState,
                backButton: false,
              ),
            ),
            SizedBox(height: height * 0.025),
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
                    appState.appSettings.songPlaces.isEmpty
                        ? null
                        : () {
                          debugPrint("Pressed");
                          appState.appSettings.firstTime = false;
                          appState.updateAppSettings();
                          Navigator.push(context, AppLoadingScreen.route());
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
      },
    );
  }
}
