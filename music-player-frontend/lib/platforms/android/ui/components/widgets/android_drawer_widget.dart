import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/drawer_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/local_libs/hover_widget/hover_container.dart';
import 'package:music_player_frontend/platforms/android/ui/components/linux_scaler.dart';
import 'package:music_player_frontend/platforms/android/ui/components/theme.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/albums.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/artists.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/playlists.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/settings_screen.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/tracks.dart';
import 'package:provider/provider.dart';

class AndroidDrawerWidget extends DrawerWidget {
  const AndroidDrawerWidget({super.key, required this.selectedIndex});

  final int selectedIndex;

  @override
  State<DrawerWidget> createState() => _LinuxDrawerWidgetState();
}

class _LinuxDrawerWidgetState extends DrawerWidgetState {
  late int _selected;
  late AbstractAppStateProvider _appStateProvider;

  AndroidDrawerWidget get _widget => widget as AndroidDrawerWidget;

  List<Map<String, dynamic>> get menuItems => [
    {
      "text": "Albums",
      "tooltip": "Albums",
      "icon": FluentIcons.album,
      "index": 1,
      "onTap": (BuildContext context) {
        setState(() => _selected = 1);
        _appStateProvider.navigatorKey.currentState!.push(Albums.route());
      },
    },
    {
      "text": "Artists",
      "tooltip": "Artists",
      "icon": FluentIcons.artists2,
      "index": 2,
      "onTap": (BuildContext context) {
        setState(() => _selected = 2);
        _appStateProvider.navigatorKey.currentState!.push(Artists.route());
      },
    },
    {
      "text": "Music",
      "tooltip": "Music",
      "icon": FluentIcons.music,
      "index": 3,
      "onTap": (BuildContext context) {
        setState(() => _selected = 3);
        _appStateProvider.navigatorKey.currentState!.push(Tracks.route());
      },
    },
    {
      "text": "Playlists",
      "tooltip": "Playlists",
      "icon": FluentIcons.playlists,
      "index": 4,
      "onTap": (BuildContext context) {
        setState(() => _selected = 4);
        _appStateProvider.navigatorKey.currentState!.push(Playlists.route());
      },
    },
    {
      "text": "Settings",
      "tooltip": "Settings",
      "icon": FluentIcons.settings,
      "index": 5,
      "onTap": (BuildContext context) {
        setState(() => _selected = 5);
        _appStateProvider.navigatorKey.currentState!.push(
          SettingsScreen.route(),
        );
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _selected = _widget.selectedIndex;
  }

  Widget _buildMenuItem({
    required Map<String, dynamic> item,
    required double width,
    required double height,
  }) {
    final int itemIndex = item["index"];
    final bool isSelected = _selected == itemIndex;

    return AnimatedContainer(
      height: height * 0.05,
      duration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: isSelected ? null : () => item["onTap"](context),
          child: HoverContainer(
            hoverColor: Colors.indigo.withValues(alpha: 0.2),
            normalColor:
                isSelected
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.transparent,
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.01,
              vertical: height * 0.01,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Fixed width container for icon to prevent shifting
                SizedBox(
                  width: width * 0.0125,
                  child: Icon(
                    item["icon"],
                    size: LinuxScaler.scale(context, 24),
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: Text(
                    item["text"],
                    style: MusicPlayerTheme.getTheme(
                      context,
                    ).textTheme.bodyLarge!.copyWith(
                      color:
                          isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildDrawer(BuildContext context) {
    _appStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );

    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    return SafeArea(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: width * 0.65,
        curve: Curves.easeInOut,
        alignment: Alignment.center,
        child: GlassContainer(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.40),
              Colors.black.withOpacity(0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderColor: Colors.transparent,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(height * 0.015),
            bottomRight: Radius.circular(height * 0.015),
          ),
          blur: 45.0,
          borderWidth: 0.0,
          elevation: 3.0,
          shadowColor: Colors.black.withOpacity(0.20),
          alignment: Alignment.center,
          shape: BoxShape.rectangle,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Menu items
              ...menuItems.map(
                (item) =>
                    _buildMenuItem(item: item, width: width, height: height),
              ),

              const Spacer(),
              // User section at bottom
              AnimatedContainer(
                height: height * 0.07,
                duration: const Duration(milliseconds: 300),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap:
                        _selected == 6
                            ? null
                            : () => setState(() => _selected = 6),
                    child: HoverContainer(
                      hoverColor: Colors.indigo.withValues(alpha: 0.2),
                      normalColor:
                          _selected == 6
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.transparent,
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.01,
                        vertical: height * 0.01,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: width * 0.0125,
                            child: CircleAvatar(
                              radius: height * 0.0125,
                              backgroundColor: Colors.indigo.withOpacity(0.3),
                              child: Icon(
                                FluentIcons.circlePerson,
                                size: LinuxScaler.scale(context, 24),
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: width * 0.01),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "User Name",
                                  style:
                                      MusicPlayerTheme.getTheme(
                                        context,
                                      ).textTheme.bodyLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  "user@email.com",
                                  style: MusicPlayerTheme.getTheme(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
