import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/user.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/widgets/drawer_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/local_libs/hover_widget/hover_container.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/linux_scaler.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/albums.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/artists.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/playlists.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/tracks.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/upload_songs_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/user_settings_screen.dart';
import 'package:provider/provider.dart';

class WebDrawerWidget extends DrawerWidget {
  const WebDrawerWidget({super.key});

  @override
  State<DrawerWidget> createState() => _LinuxDrawerWidgetState();
}

class _LinuxDrawerWidgetState extends DrawerWidgetState {
  bool _finishedAnimation = true;
  int _selected = 3;
  late AbstractAppStateProvider _appStateProvider;

  List<Map<String, dynamic>> get menuItems => [
    {
      "text": "Albums",
      "tooltip": "Albums",
      "icon": FluentIcons.album,
      "index": 1,
      "onTap": (BuildContext context) {
        setState(() => _selected = 1);
        _appStateProvider.innerNavigatorKey.currentState!.push(Albums.route());
      },
    },
    {
      "text": "Artists",
      "tooltip": "Artists",
      "icon": FluentIcons.artists2,
      "index": 2,
      "onTap": (BuildContext context) {
        setState(() => _selected = 2);
        _appStateProvider.innerNavigatorKey.currentState!.push(Artists.route());
      },
    },
    {
      "text": "Music",
      "tooltip": "Music",
      "icon": FluentIcons.music,
      "index": 3,
      "onTap": (BuildContext context) {
        setState(() => _selected = 3);
        _appStateProvider.innerNavigatorKey.currentState!.push(Tracks.route());
      },
    },
    {
      "text": "Playlists",
      "tooltip": "Playlists",
      "icon": FluentIcons.playlists,
      "index": 4,
      "onTap": (BuildContext context) {
        setState(() => _selected = 4);
        _appStateProvider.innerNavigatorKey.currentState!.push(
          Playlists.route(),
        );
      },
    },
  ];

  List<Map<String, dynamic>> get adminMenuItems => [
    {
      "text": "Upload songs",
      "tooltip": "Upload songs",
      "icon": FluentIcons.download,
      "index": 6,
      "onTap": (BuildContext context) {
        setState(() => _selected = 6);
        context
            .read<AbstractAppStateProvider>()
            .innerNavigatorKey
            .currentState!
            .push(LinuxUploadSongsScreen.route());
      },
    },
  ];

  void _toggleDrawer() {
    if (_appStateProvider.appSettings.drawerOpen) {
      setState(() => _finishedAnimation = false);
      _appStateProvider.setDrawerOpen(false);
    } else {
      _appStateProvider.setDrawerOpen(true);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _finishedAnimation = true);
      });
    }
  }

  Widget _buildMenuItem({
    required Map<String, dynamic> item,
    required double width,
    required double height,
    required bool isDrawerOpen,
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
                    size: LinuxScaler().scale(context, 24),
                    color: Colors.white,
                  ),
                ),
                if (isDrawerOpen) ...[
                  SizedBox(width: width * 0.01),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _finishedAnimation ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        item["text"],
                        style: MusicPlayerTheme.getTheme(
                          context,
                          context.read<Scaler>(),
                        ).textTheme.bodyLarge!.copyWith(
                          color:
                              isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
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

    return Selector<AbstractAppStateProvider, bool>(
      selector: (_, appState) => _appStateProvider.appSettings.drawerOpen,
      builder: (context, isDrawerOpen, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isDrawerOpen ? width * 0.12 : width * 0.0325,
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          child: GlassContainer(
            color: Colors.black.withValues(alpha: 0.4),
            borderColor: Colors.transparent,
            borderRadius: BorderRadius.circular(
              MediaQuery.of(context).size.height * 0.015,
            ),
            blur: 45.0,
            borderWidth: 0.0,
            elevation: 3.0,
            shadowColor: Colors.black.withValues(alpha: 0.20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Menu toggle button
                AnimatedContainer(
                  height: height * 0.05,
                  duration: const Duration(milliseconds: 300),
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
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: isDrawerOpen ? null : _toggleDrawer,
                          icon: Icon(
                            FluentIcons.menu,
                            size: LinuxScaler().scale(context, 22),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (isDrawerOpen) ...[
                        const Spacer(),
                        AnimatedOpacity(
                          opacity: _finishedAnimation ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _toggleDrawer,
                            icon: Icon(
                              FluentIcons.drawerOff,
                              color: Colors.white,
                              size: LinuxScaler().scale(context, 22),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Menu items
                ...menuItems.map(
                  (item) => _buildMenuItem(
                    item: item,
                    width: width,
                    height: height,
                    isDrawerOpen: isDrawerOpen,
                  ),
                ),

                Selector<UserProvider, User?>(
                  selector: (_, userProvider) => userProvider.currentUser,
                  builder: (context, currentUser, child) {
                    if (currentUser == null || !currentUser.isAdmin) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        const Divider(
                          color: Colors.white24,
                          thickness: 1,
                          indent: 8,
                          endIndent: 8,
                        ),
                        ...adminMenuItems.map(
                          (item) => _buildMenuItem(
                            item: item,
                            width: width,
                            height: height,
                            isDrawerOpen: isDrawerOpen,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                StreamBuilder<double>(
                  stream:
                      context
                          .read<AbstractMusicScannerService>()
                          .progressStream,
                  initialData: 2.0,
                  builder: (context, snapshot) {
                    final progress = snapshot.data ?? 2.0;

                    final toBeShown = progress >= 0.0 && progress <= 1.0;
                    final isFinished = progress == 1.0;

                    if (isFinished) {
                      debugPrint("Refresh after metadata enrichment finished.");
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        context.read<SongProvider>().refreshSongs();
                      });
                    }

                    return AnimatedContainer(
                      height: height * 0.05,
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.01,
                        vertical: height * 0.01,
                      ),
                      alignment: Alignment.center,
                      child:
                          toBeShown
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: width * 0.0125,
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                        value: progress > 0 ? progress : null,
                                      ),
                                    ),
                                  ),
                                  if (isDrawerOpen) ...[
                                    SizedBox(width: width * 0.01),
                                    Expanded(
                                      child: AnimatedOpacity(
                                        opacity:
                                            !isFinished && _finishedAnimation
                                                ? 1.0
                                                : 0.0,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        child: Text(
                                          isFinished
                                              ? "Complete"
                                              : "Scanning...",
                                          style: MusicPlayerTheme.getTheme(
                                            context,
                                            context.read<Scaler>(),
                                          ).textTheme.bodyLarge!.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                              : const SizedBox.shrink(),
                    );
                  },
                ),

                const Spacer(),

                AnimatedContainer(
                  height: height * 0.07,
                  duration: const Duration(milliseconds: 300),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selected = 5);
                        _appStateProvider.innerNavigatorKey.currentState!.push(
                          UserSettingsScreen.route(),
                        );
                      },
                      child: HoverContainer(
                        hoverColor: Colors.indigo.withValues(alpha: 0.2),
                        normalColor:
                            _selected == 5
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
                                backgroundColor: Colors.indigo.withValues(
                                  alpha: 0.3,
                                ),
                                child: Icon(
                                  FluentIcons.settings,
                                  size: LinuxScaler().scale(context, 24),
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (isDrawerOpen) ...[
                              SizedBox(width: width * 0.01),
                              Expanded(
                                child: AnimatedOpacity(
                                  opacity: _finishedAnimation ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "User Settings",
                                        style:
                                            MusicPlayerTheme.getTheme(
                                              context,
                                              context.read<Scaler>(),
                                            ).textTheme.bodyLarge,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Selector<UserProvider, User?>(
                                        selector:
                                            (_, userProvider) =>
                                                userProvider.currentUser,
                                        builder: (context, user, child) {
                                          return Text(
                                            user?.email ?? "Not logged in",
                                            style: MusicPlayerTheme.getTheme(
                                              context,
                                              context.read<Scaler>(),
                                            ).textTheme.bodyMedium!.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
