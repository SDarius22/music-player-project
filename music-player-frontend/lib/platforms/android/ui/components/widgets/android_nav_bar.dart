import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/albums.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/artists.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/playlists.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/tracks.dart';
import 'package:provider/provider.dart';

class AndroidNavigationBar extends StatefulWidget {
  const AndroidNavigationBar({super.key});

  @override
  State<AndroidNavigationBar> createState() => _AndroidNavigationBarState();
}

class _AndroidNavigationBarState extends State<AndroidNavigationBar> {
  late int _selected = 2;
  late AbstractAppStateProvider _appStateProvider;

  List<Map<String, dynamic>> get menuItems => [
    {
      "text": "Albums",
      "tooltip": "Albums",
      "icon": FluentIcons.album,
      "index": 0,
      "onTap": (BuildContext context) {
        setState(() => _selected = 0);
        _appStateProvider.navigatorKey.currentState!.push(Albums.route());
      },
    },
    {
      "text": "Artists",
      "tooltip": "Artists",
      "icon": FluentIcons.artists2,
      "index": 1,
      "onTap": (BuildContext context) {
        setState(() => _selected = 1);
        _appStateProvider.navigatorKey.currentState!.push(Artists.route());
      },
    },
    {
      "text": "Music",
      "tooltip": "Music",
      "icon": FluentIcons.music,
      "index": 2,
      "onTap": (BuildContext context) {
        setState(() => _selected = 2);
        _appStateProvider.navigatorKey.currentState!.push(Tracks.route());
      },
    },
    {
      "text": "Playlists",
      "tooltip": "Playlists",
      "icon": FluentIcons.playlists,
      "index": 3,
      "onTap": (BuildContext context) {
        setState(() => _selected = 3);
        _appStateProvider.navigatorKey.currentState!.push(Playlists.route());
      },
    },
  ];

  @override
  Widget build(BuildContext context) {
    _appStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );

    return BottomNavigationBar(
      type: BottomNavigationBarType.shifting,
      currentIndex: _selected,
      items:
          menuItems.map((item) {
            return BottomNavigationBarItem(
              icon: Icon(item["icon"]),
              label: item["text"],
              tooltip: item["tooltip"],
            );
          }).toList(),
      onTap: (index) {
        menuItems[index]["onTap"](context);
      },
    );
  }
}
