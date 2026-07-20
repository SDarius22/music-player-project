import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/features/auth/presentation/providers/user_provider.dart';
import 'package:music_player_frontend/app/theme/music_player_theme.dart';
import 'package:music_player_frontend/features/auth/presentation/screens/login_screen.dart';
import 'package:music_player_frontend/features/library/presentation/playlist_import_actions.dart';
import 'package:music_player_frontend/features/library/presentation/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/shared/presentation/scaffolds/glass_scaffold.dart';
import 'package:provider/provider.dart';

import 'package:music_player_frontend/shared/presentation/navigation/route_builder.dart';

class UserSettingsScreen extends StatefulWidget {
  static Route<void> route() {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => const UserSettingsScreen(),
      settings: const RouteSettings(name: "/user_settings"),
    );
  }

  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  static const _networkModeLabels = [
    'WiFi only',
    'Cellular only',
    'WiFi + Cellular',
  ];

  void _saveSettings(BuildContext context) {
    context.read<AbstractAppStateProvider>().updateAppSettings();
  }

  AppSettings _settings(BuildContext context) =>
      context.read<AbstractAppStateProvider>().appSettings;

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
                  LoginScreen.route(),
                );
              },
              child: Text(
                "Login / Register",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Colors.white),
              ),
            );
          },
        ),
      },

      {
        "title": const Text("Playlists"),
        "subtitle": const Text(
          "Import M3U/M3U8 playlists or export several playlists at once.",
        ),
        "trailing": Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => PlaylistImportActions.importPlaylist(context),
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text("Import"),
            ),
            ElevatedButton.icon(
              onPressed: () {
                context
                    .read<AbstractAppStateProvider>()
                    .innerNavigatorKey
                    .currentState
                    ?.push(AddOrExportScreen.route(export: true));
              },
              icon: const Icon(Icons.file_download_outlined),
              label: const Text("Export"),
            ),
          ],
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
          style: Theme.of(
            context,
          ).textTheme.bodySmall!.copyWith(color: Colors.grey.shade300),
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
                  valueIndicatorTextStyle: Theme.of(
                    context,
                  ).textTheme.bodySmall!.copyWith(color: Colors.black),
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

      // Peer Network Mode
      {
        "title": Text(
          "Peer Network",
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        "subtitle": Text(
          "Choose which connection types allow peer-to-peer streaming.",
          style: Theme.of(
            context,
          ).textTheme.bodySmall!.copyWith(color: Colors.grey.shade300),
        ),
        "trailing": Consumer<AbstractAppStateProvider>(
          builder: (context, appState, _) {
            return DropdownButton<int>(
              value: appState.appSettings.peerNetworkMode,
              dropdownColor: Colors.black87,
              style: Theme.of(
                context,
              ).textTheme.bodySmall!.copyWith(color: Colors.white),
              underline: const SizedBox.shrink(),
              items: List.generate(
                _networkModeLabels.length,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(_networkModeLabels[i]),
                ),
              ),
              onChanged: (v) {
                if (v == null) return;
                appState.appSettings.peerNetworkMode = v;
                _saveSettings(context);
              },
            );
          },
        ),
      },

      // WiFi data limit (visible when WiFi is included: modes 0 and 2)
      ...() {
        final mode = _settings(context).peerNetworkMode;
        if (mode != 0 && mode != 2) return <Map<String, Widget>>[];
        return [
          {
            "title": Text(
              "WiFi Data Limit",
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.normal,
                color: Colors.white,
              ),
            ),
            "subtitle": Consumer<AbstractAppStateProvider>(
              builder: (context, appState, _) {
                final limit = appState.appSettings.peerWifiDataLimitGB;
                return Text(
                  limit == -1 ? "Unlimited" : "$limit GB",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall!.copyWith(color: Colors.grey.shade300),
                );
              },
            ),
            "trailing": Consumer<AbstractAppStateProvider>(
              builder: (context, appState, _) {
                final raw = appState.appSettings.peerWifiDataLimitGB;
                // Slider value: 0 = unlimited, 1–20 = 1–20 GB
                final sliderVal = raw == -1 ? 0.0 : raw.clamp(1, 20).toDouble();
                return SizedBox(
                  width: MediaQuery.of(context).size.width * 0.15,
                  child: SliderTheme(
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
                      valueIndicatorTextStyle: Theme.of(
                        context,
                      ).textTheme.bodySmall!.copyWith(color: Colors.black),
                      valueIndicatorShape:
                          const PaddleSliderValueIndicatorShape(),
                    ),
                    child: Slider(
                      min: 0,
                      max: 20,
                      divisions: 20,
                      value: sliderVal,
                      label:
                          sliderVal == 0
                              ? "Unlimited"
                              : "${sliderVal.toInt()} GB",
                      onChanged: (v) {
                        appState.appSettings.peerWifiDataLimitGB =
                            v == 0 ? -1 : v.toInt();
                        _saveSettings(context);
                      },
                    ),
                  ),
                );
              },
            ),
          },
        ];
      }(),

      // Cellular data limit (visible when cellular is included: modes 1 and 2)
      ...() {
        final mode = _settings(context).peerNetworkMode;
        if (mode != 1 && mode != 2) return <Map<String, Widget>>[];
        return [
          {
            "title": Text(
              "Cellular Data Limit",
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.normal,
                color: Colors.white,
              ),
            ),
            "subtitle": Consumer<AbstractAppStateProvider>(
              builder: (context, appState, _) {
                final limit = appState.appSettings.peerCellularDataLimitGB;
                return Text(
                  limit == -1 ? "Unlimited" : "$limit GB",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall!.copyWith(color: Colors.grey.shade300),
                );
              },
            ),
            "trailing": Consumer<AbstractAppStateProvider>(
              builder: (context, appState, _) {
                // Cellular limit must be at least 1 GB; -1 = unlimited,
                // represented as slider position 0.
                final raw = appState.appSettings.peerCellularDataLimitGB;
                final sliderVal = raw == -1 ? 0.0 : raw.clamp(1, 20).toDouble();
                return SizedBox(
                  width: MediaQuery.of(context).size.width * 0.15,
                  child: SliderTheme(
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
                      valueIndicatorTextStyle: Theme.of(
                        context,
                      ).textTheme.bodySmall!.copyWith(color: Colors.black),
                      valueIndicatorShape:
                          const PaddleSliderValueIndicatorShape(),
                    ),
                    child: Slider(
                      min: 0,
                      max: 20,
                      divisions: 20,
                      value: sliderVal,
                      label:
                          sliderVal == 0
                              ? "Unlimited"
                              : "${sliderVal.toInt()} GB",
                      onChanged: (v) {
                        appState.appSettings.peerCellularDataLimitGB =
                            v == 0 ? -1 : v.toInt();
                        _saveSettings(context);
                      },
                    ),
                  ),
                );
              },
            ),
          },
        ];
      }(),
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
