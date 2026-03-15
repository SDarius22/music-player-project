import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/user.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/screens/albums.dart';
import 'package:music_player_frontend/core/ui/screens/artists.dart';
import 'package:music_player_frontend/core/ui/screens/playlists.dart';
import 'package:music_player_frontend/core/ui/screens/tracks.dart';
import 'package:music_player_frontend/core/ui/screens/upload_songs_screen.dart';
import 'package:music_player_frontend/core/ui/screens/user_settings_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/local_libs/hover_widget/hover_container.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

class DrawerWidget extends StatefulWidget {
  final bool mobileDrawer;

  const DrawerWidget({super.key, this.mobileDrawer = false});

  @override
  State<DrawerWidget> createState() => _DrawerWidgetState();
}

class _DrawerWidgetState extends State<DrawerWidget> {
  int _selected = 3;
  late AbstractAppStateProvider _appStateProvider;

  @override
  Widget build(BuildContext context) {
    return buildDrawer(context);
  }

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
            .push(UploadSongsScreen.route());
      },
    },
  ];

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
      alignment: Alignment.center,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: isSelected ? null : () {
            item["onTap"](context);
            if (widget.mobileDrawer) Scaffold.of(context).closeDrawer();
          },
          child: HoverContainer(
            hoverColor: Colors.indigo.withValues(alpha: 0.2),
            normalColor:
                isSelected
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.transparent,
            padding: EdgeInsets.symmetric(
              horizontal: isDrawerOpen ? width * 0.01 : 0,
              vertical: height * 0.01,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: width * 0.0125,
                  child: Icon(
                    item["icon"],
                    size: context.read<Scaler>().scale(context, 24),
                    color: Colors.white,
                  ),
                ),
                if (isDrawerOpen) ...[
                  SizedBox(width: width * 0.01),
                  Expanded(
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color brighten(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final brighterHsl = hsl.withLightness(
      (hsl.lightness + amount).clamp(0.0, 1.0),
    );
    return brighterHsl.toColor();
  }

  Widget buildDrawer(BuildContext context) {
    _appStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );

    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    bool isDrawerOpen =
        widget.mobileDrawer ||
        ResponsiveBreakpoints.of(context).isDesktop ||
        ResponsiveBreakpoints.of(context).equals('4K');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width:
          widget.mobileDrawer
              ? double.infinity
              : (isDrawerOpen ? width * 0.12 : width * 0.05),
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
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
                  context.read<AbstractMusicScannerService>().progressStream,
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
                            mainAxisAlignment:
                                isDrawerOpen
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.center,
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
                                    opacity: !isFinished ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    child: Text(
                                      isFinished ? "Complete" : "Scanning...",
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
                    if (widget.mobileDrawer) Scaffold.of(context).closeDrawer();
                  },
                  child: HoverContainer(
                    hoverColor: Colors.indigo.withValues(alpha: 0.2),
                    normalColor:
                        _selected == 5
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.transparent,
                    padding: EdgeInsets.symmetric(
                      horizontal: isDrawerOpen ? width * 0.01 : 0,
                      vertical: height * 0.01,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment:
                          isDrawerOpen
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
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
                              size: context.read<Scaler>().scale(context, 24),
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (isDrawerOpen) ...[
                          SizedBox(width: width * 0.01),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
  }
}
