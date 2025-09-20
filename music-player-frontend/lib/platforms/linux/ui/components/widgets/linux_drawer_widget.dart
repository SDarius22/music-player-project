import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/drawer_widget.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/widgets/linux_actions_widget.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/albums.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/artists.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/playlists.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/settings_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/tracks.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/hover_widget/hover_container.dart';
import 'package:provider/provider.dart';

class LinuxDrawerWidget extends DrawerWidget {
  const LinuxDrawerWidget({super.key});

  @override
  State<DrawerWidget> createState() => _LinuxDrawerWidgetState();
}

class _LinuxDrawerWidgetState extends DrawerWidgetState {
  bool _finishedAnimation = false;
  int _selected = 4;
  late AbstractAppStateProvider _appStateProvider;
  late List<Map<String, dynamic>> menuItems = [
    {
      "text": "Menu",
      "tooltip": "Expand Menu",
      "icon": FluentIcons.menu,
      "onTap": (BuildContext context) {
        if (_appStateProvider.isDrawerOpen == false) {
          _appStateProvider.setDrawerOpen(true);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _finishedAnimation = true;
              });
            }
          });
        } else {
          _appStateProvider.setDrawerOpen(false);
        }
      },
    },
    {
      "text": "User Page",
      "tooltip": "User Page",
      "icon": FluentIcons.circlePerson,
      "onTap": (BuildContext context) {
        setState(() {
          _selected = 1;
        });
        _appStateProvider.navigatorKey.currentState!.pushNamed('/user');
      },
    },
    {
      "text": "Albums",
      "tooltip": "Albums",
      "icon": FluentIcons.album,
      "onTap": (BuildContext context) {
        setState(() {
          _selected = 2;
        });
        _appStateProvider.navigatorKey.currentState!.push(Albums.route());
      },
    },
    {
      "text": "Artists",
      "tooltip": "Artists",
      "icon": FluentIcons.artists2,
      "onTap": (BuildContext context) {
        setState(() {
          _selected = 3;
        });
        _appStateProvider.navigatorKey.currentState!.push(Artists.route());
      },
    },
    {
      "text": "Music",
      "tooltip": "Music",
      "icon": FluentIcons.music,
      "onTap": (BuildContext context) {
        setState(() {
          _selected = 4;
        });
        _appStateProvider.navigatorKey.currentState!.push(Tracks.route());
      },
    },
    {
      "text": "Playlists",
      "tooltip": "Playlists",
      "icon": FluentIcons.playlists,
      "onTap": (BuildContext context) {
        setState(() {
          _selected = 5;
        });
        _appStateProvider.navigatorKey.currentState!.push(Playlists.route());
      },
    },
    {
      "text": "Settings",
      "tooltip": "Settings",
      "icon": FluentIcons.settings,
      "onTap": (BuildContext context) {
        setState(() {
          _selected = 6;
        });
        //_appStateProvider.panelController.isAttached ? _appStateProvider.panelController.close() : null;
        _appStateProvider.navigatorKey.currentState!.push(
          SettingsScreen.route(),
        );
      },
    },
    // {
    //   "text": "Create",
    //   "tooltip": "Create",
    //   "icon": FluentIcons.create,
    //   "onTap": (BuildContext context) {
    //     setState(() {
    //       _selected = 8;
    //     });
    //     _appStateProvider.navigatorKey.currentState!.push(CreateScreen.route(args: [""]));
    //   }
    // },
    // {
    //   "text": "Contact us",
    //   "tooltip": "Contact us",
    //   "icon": FluentIcons.open,
    //   "onTap": (BuildContext context) {}, // Placeholder for contact action
    // },
    // {
    //   "text": "About us",
    //   "tooltip": "About us",
    //   "icon": FluentIcons.open,
    //   "onTap": (BuildContext context) {
    //     showAboutDialog(
    //       context: context,
    //       applicationIcon: Image.asset(
    //         'assets/logo.png',
    //         fit: BoxFit.cover,
    //         width: MediaQuery.of(context).size.width * 0.075,
    //         height: MediaQuery.of(context).size.width * 0.075,
    //       ),
    //       applicationName: 'Music Player',
    //       applicationVersion: 'version: 0.0.1',
    //       applicationLegalese: '© 2025 Music Player',
    //       children: const [
    //         Text('Music Player is a free and open-source music player for Windows, Linux and Android.'),
    //         Text('Developed by: Darius Sala'),
    //         Text(''),
    //         Text('This software is provided as-is, without any warranty or guarantee of any kind. Use at your own risk.'),
    //       ],
    //     );
    //   },
    // },
  ];

  @override
  Widget buildDrawer(BuildContext context) {
    _appStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );

    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    var normalSize = height * 0.02;
    return Consumer<AbstractAppStateProvider>(
      builder: (context, appState, child) {
        return AnimatedContainer(
          width: appState.isDrawerOpen ? width * 0.12 : width * 0.035,
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E0E),
            border: Border(
              right: BorderSide(color: _appStateProvider.darkColor, width: 1.0),
            ),
          ),
          child: Column(
            children: [
              Flexible(
                child: ListView.builder(
                  itemCount: menuItems.length,
                  itemExtent: height * 0.05,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    return AnimatedContainer(
                      height: height * 0.05,
                      duration: const Duration(milliseconds: 300),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Tooltip(
                          message: menuItems[index]["tooltip"],
                          child: GestureDetector(
                            onTap:
                                _selected == index
                                    ? null
                                    : () {
                                      menuItems[index]["onTap"](context);
                                    },
                            child: HoverContainer(
                              hoverColor: brighten(
                                _selected == index
                                    ? _appStateProvider.darkColor
                                    : const Color(0xFF0E0E0E),
                                0.05,
                              ),
                              normalColor:
                                  _selected == index
                                      ? _appStateProvider.darkColor
                                      : const Color(0xFF0E0E0E),
                              padding: EdgeInsets.symmetric(
                                horizontal: width * 0.01,
                                vertical: height * 0.01,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    menuItems[index]["icon"],
                                    size: height * 0.025,
                                    color: Colors.white,
                                  ),
                                  if (appState.isDrawerOpen &&
                                      _finishedAnimation)
                                    Expanded(
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        padding: EdgeInsets.only(
                                          left: width * 0.01,
                                        ),
                                        child: Text(
                                          menuItems[index]["text"],
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: normalSize,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const LinuxActionsWidget(),
            ],
          ),
        );
      },
    );
  }
}
