import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/screens/app_login_register_screen.dart';
import 'package:music_player_frontend/core/ui/screens/user_settings_screen.dart';
import 'package:provider/provider.dart';

class AppUserSettingsScreen extends AbstractUserSettingsScreen {
  static Route<void> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return const AppUserSettingsScreen();
      },
    );
  }

  const AppUserSettingsScreen({super.key});

  @override
  AbstractUserSettingsScreenState createState() =>
      _AppUserSettingsScreenState();
}

class _AppUserSettingsScreenState
    extends AbstractUserSettingsScreenState<AppUserSettingsScreen> {
  @override
  List<Map<String, Widget>> get settingsMap {
    var height = MediaQuery.of(context).size.height;
    var normalSize = height * 0.02;
    var smallSize = height * 0.015;

    final audioProvider = Provider.of<AudioProvider>(context, listen: false);

    return [
      {
        "title": const Text("Account"),
        "subtitle": Consumer<UserProvider>(
          builder: (context, userProvider, _) {
            return Text(
              userProvider.isAuthenticated
                  ? "You are signed in. Tap logout to sign out."
                  : "Sign in or create an account.",
            );
          },
        ),
        "trailing": Consumer<UserProvider>(
          builder: (context, userProvider, _) {
            if (userProvider.isAuthenticated) {
              return FilledButton(
                onPressed: () async {
                  await context.read<UserProvider>().logout();
                },
                child: const Text("Logout"),
              );
            }

            return ElevatedButton(
              onPressed: () {
                final appState = context.read<AbstractAppStateProvider>();
                appState.innerNavigatorKey.currentState?.push(
                  AppLoginRegisterScreen.route(),
                );
              },
              child: Text(
                "Login / Register",
                style: TextStyle(color: Colors.white, fontSize: normalSize),
              ),
            );
          },
        ),
      },

      // Playback Speed
      {
        "title": Text(
          "Playback Speed",
          style: TextStyle(
            fontSize: normalSize,
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        "subtitle": Text(
          "Set the playback speed to a certain value",
          style: TextStyle(fontSize: smallSize, color: Colors.grey.shade300),
        ),
        "trailing": SizedBox(
          width: MediaQuery.of(context).size.width * 0.15,
          child: ValueListenableBuilder(
            valueListenable: audioProvider.playbackSpeedNotifier,
            builder: (context, value, child) {
              return SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbColor: Colors.white,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: height * 0.0075,
                  ),
                  showValueIndicator: ShowValueIndicator.onDrag,
                  activeTrackColor: MusicPlayerTheme.primaryPurple,
                  inactiveTrackColor: Colors.white,
                  valueIndicatorColor: Colors.white,
                  valueIndicatorTextStyle: TextStyle(
                    fontSize: smallSize,
                    color: Colors.black,
                  ),
                  valueIndicatorShape:
                      const PaddleSliderValueIndicatorShape(),
                ),
                child: Slider(
                  min: 0.0,
                  max: 2.0,
                  divisions: 20,
                  label: "${value.toStringAsPrecision(2)}x",
                  mouseCursor: SystemMouseCursors.click,
                  value: value,
                  onChanged: (double value) {
                    audioProvider.setPlaybackSpeed(value);
                  },
                ),
              );
            },
          ),
        ),
      },
    ];
  }

  @override
  EdgeInsetsGeometry buildPadding(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    return EdgeInsets.symmetric(
      horizontal: width * 0.025,
      vertical: height * 0.025,
    );
  }
}