import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/screens/login_register_screen.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:provider/provider.dart';

class UserSettingsScreen extends StatefulWidget {
  static Route<void> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: "/settings"),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const UserSettingsScreen();
      },
    );
  }

  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  String dropDownValue = "Off";

  List<Map<String, Widget>> get settingsMap {
    var height = MediaQuery.of(context).size.height;

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
                  LoginRegisterScreen.route(mode: AuthMode.login),
                );
              },
              child: Text(
                "Login / Register",
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white),
              ),
            );
          },
        ),
      },

      // Playback Speed
      {
        "title": Text(
          "Playback Speed",
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        "subtitle": Text(
          "Set the playback speed to a certain value",
          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.grey.shade300),
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
                  activeTrackColor: MusicPlayerTheme.gradientViolet,
                  inactiveTrackColor: Colors.white,
                  valueIndicatorColor: Colors.white,
                  valueIndicatorTextStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Colors.black,
                  ),
                  valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
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
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: buildAppBar(context),
      body: Padding(
        padding: buildPadding(context),
        child: Consumer<AbstractAppStateProvider>(
          builder: (_, appState, _) {
            return ListView.builder(
              itemCount: settingsMap.length,
              itemBuilder: (context, index) {
                var setting = settingsMap[index];
                return ListTile(
                  title: setting['title'],
                  subtitle: setting['subtitle'],
                  trailing: setting['trailing'],
                );
              },
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    return const PreferredSize(
      preferredSize: Size.fromHeight(0),
      child: SizedBox.shrink(),
    );
  }

  EdgeInsetsGeometry buildPadding(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    return EdgeInsets.symmetric(
      horizontal: width * 0.025,
      vertical: height * 0.025,
    );
  }
}
