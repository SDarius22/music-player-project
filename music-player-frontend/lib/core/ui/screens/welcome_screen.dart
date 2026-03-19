import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/app_bar_widget.dart';
import 'package:music_player_frontend/core/ui/screens/library_settings_screen.dart';
import 'package:music_player_frontend/core/ui/screens/loading_screen.dart';
import 'package:music_player_frontend/core/ui/screens/login_register_screen.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_animated_scaffold.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';
import 'package:universal_platform/universal_platform.dart';

class WelcomeScreen extends StatefulWidget {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: "/welcome"),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const WelcomeScreen();
      },
    );
  }

  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    return GlassAnimatedScaffold(
      controller: context.read<AbstractAppStateProvider>().gradientController,
      appBar: AppBarWidget(),
      body: Container(
        alignment: Alignment.center,
        padding: buildPadding(context),
        child: buildBody(context),
      ),
    );
  }

  EdgeInsetsGeometry buildPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: MediaQuery.of(context).size.height * 0.015,
      vertical: MediaQuery.of(context).size.height * 0.015,
    );
  }

  Widget buildBody(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Consumer<AbstractAppStateProvider>(
      builder: (context, appState, child) {
        return SizedBox(
          width: width * 0.8,
          height: height * 0.8,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Welcome to Music Player!",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: height * 0.025),
              if (UniversalPlatform.isWeb) ...[
                SizedBox(
                  width: width * 0.75,
                  height: height * 0.5,
                  child: LoginRegisterScreen(mode: AuthMode.login),
                ),
              ] else ...[
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
                              Navigator.push(context, LoadingScreen.route());
                            },
                    child: Icon(
                      FluentIcons.forward,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
