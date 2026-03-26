import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ipwhois/ipwhois.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/home_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:provider/provider.dart';

const double _mobileBreakpoint = 600;

class HomeScreen extends StatefulWidget {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/home'),
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(opacity: animation, child: const HomeScreen());
      },
    );
  }

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().load();
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final theme = MusicPlayerTheme.getTheme();
    final isMobile = width < _mobileBreakpoint;
    final hPad = isMobile ? width * 0.04 : width * 0.015;

    return GlassScaffold(
      body: RefreshIndicator(
        onRefresh: () => context.read<HomeProvider>().refresh(),
        color: Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, hPad, hPad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Selector<UserProvider, (String, IpInfo?)>(
                      selector:
                          (_, p) => (p.currentUser?.email ?? '', p.ipInfo),
                      builder: (context, data, _) {
                        final (email, ipInfo) = data;
                        final name =
                            email.isNotEmpty ? email.split('@').first : '';
                        final ipAddress = ipInfo?.ip ?? '';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isNotEmpty
                                  ? '${_greeting()}, $name!'
                                  : _greeting(),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (ipAddress.isNotEmpty)
                              Text(
                                ipAddress,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: isMobile ? 20 : width * 0.025),
                  ],
                ),
              ),
            ),

            Consumer<HomeProvider>(
              builder: (context, home, _) {
                if (home.loading && !home.loaded) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (home.quickDial.isNotEmpty)
                        _Section(
                          title: 'Jump back in',
                          subtitle: 'Your recent tracks',
                          songs: home.quickDial,
                          cardStyle: _CardStyle.wide,
                        ),
                      if (home.recommendations.isNotEmpty)
                        _Section(
                          title: 'Recommended for you',
                          subtitle: 'Based on your listening',
                          songs: home.recommendations,
                          cardStyle: _CardStyle.square,
                        ),
                      if (home.forgottenFavourites.isNotEmpty)
                        _Section(
                          title: 'Rediscover',
                          subtitle: "Songs you haven't heard in a while",
                          songs: home.forgottenFavourites,
                          cardStyle: _CardStyle.square,
                        ),
                      if (!home.loading &&
                          home.quickDial.isEmpty &&
                          home.recommendations.isEmpty &&
                          home.forgottenFavourites.isEmpty)
                        _EmptyState(),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.15,
                      ),
                    ]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _CardStyle { square, wide }

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Song> songs;
  final _CardStyle cardStyle;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.songs,
    required this.cardStyle,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final theme = MusicPlayerTheme.getTheme();
    final isMobile = width < _mobileBreakpoint;

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? width * 0.075 : width * 0.02),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
          SizedBox(height: width * 0.01),
          if (isMobile)
            _buildMobileLayout(context, width, theme)
          else
            _buildDesktopLayout(context, width),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    double width,
    ThemeData theme,
  ) {
    final capped =
        cardStyle == _CardStyle.wide
            ? songs.sublist(0, 6)
            : songs.sublist(0, 9);
    if (cardStyle == _CardStyle.wide) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        padding: EdgeInsets.only(top: width * 0.04),
        itemCount: capped.length,
        itemBuilder:
            (context, i) => GestureDetector(
              onTap:
                  () => context.read<AudioProvider>().setQueueAndPlay(
                    songs,
                    capped[i],
                  ),
              child: _MobileQuickDialCard(song: capped[i], theme: theme),
            ),
      );
    } else {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.75,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        padding: EdgeInsets.only(top: width * 0.04),
        itemCount: capped.length,
        itemBuilder:
            (context, i) => GestureDetector(
              onTap:
                  () => context.read<AudioProvider>().setQueueAndPlay(
                    capped,
                    capped[i],
                  ),
              child: _MobileSquareGridCard(song: capped[i], theme: theme),
            ),
      );
    }
  }

  Widget _buildDesktopLayout(BuildContext context, double width) {
    final cardWidth =
        cardStyle == _CardStyle.wide ? width * 0.22 : width * 0.14;
    final cardHeight =
        cardStyle == _CardStyle.wide ? width * 0.08 : width * 0.14;

    return SizedBox(
      height: cardHeight + width * 0.045,
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(
          scrollbars: true,
          physics: const BouncingScrollPhysics(),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: songs.length,
          separatorBuilder: (_, _) => SizedBox(width: width * 0.015),
          itemBuilder:
              (context, i) => _SongCard(
                song: songs[i],
                songs: songs,
                width: cardWidth,
                height: cardHeight,
                wide: cardStyle == _CardStyle.wide,
              ),
        ),
      ),
    );
  }
}

class _MobileQuickDialCard extends StatelessWidget {
  final Song song;
  final ThemeData theme;

  const _MobileQuickDialCard({required this.song, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Image(
              image: MemoryImage(song.coverArt ?? Uint8List(0)),
              fit: BoxFit.cover,
              errorBuilder:
                  (_, _, _) => Container(
                    color: Colors.indigo.withValues(alpha: 0.4),
                    child: Icon(
                      FluentIcons.music,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist.target?.name ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileSquareGridCard extends StatelessWidget {
  final Song song;
  final ThemeData theme;

  const _MobileSquareGridCard({required this.song, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image(
              image: MemoryImage(song.coverArt ?? Uint8List(0)),
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder:
                  (_, _, _) => Container(
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.music_note,
                        color: Colors.white38,
                        size: 32,
                      ),
                    ),
                  ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          song.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          song.artist.target?.name ?? '',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SongCard extends StatelessWidget {
  final Song song;
  final List<Song> songs;
  final double width;
  final double height;
  final bool wide;

  const _SongCard({
    required this.song,
    required this.songs,
    required this.width,
    required this.height,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MusicPlayerTheme.getTheme();

    return GestureDetector(
      onTap: () async {
        await context.read<AudioProvider>().setQueueAndPlay(songs, song);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: width,
          child:
              wide
                  ? _WideCard(
                    song: song,
                    width: width,
                    height: height,
                    theme: theme,
                  )
                  : _SquareCard(song: song, width: width, theme: theme),
        ),
      ),
    );
  }
}

class _SquareCard extends StatelessWidget {
  final Song song;
  final double width;
  final ThemeData theme;

  const _SquareCard({
    required this.song,
    required this.width,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _CoverImage(song: song, size: width),
        ),
        SizedBox(height: width * 0.05),
        Text(
          song.name,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          song.artist.target?.name ?? '',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _WideCard extends StatelessWidget {
  final Song song;
  final double width;
  final double height;
  final ThemeData theme;

  const _WideCard({
    required this.song,
    required this.width,
    required this.height,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      color: Colors.white.withValues(alpha: 0.08),
      borderColor: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      blur: 20,
      borderWidth: 0.5,
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: width * 0.05),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              child: _CoverImage(song: song, size: height),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      song.artist.target?.name ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  final Song song;
  final double size;

  const _CoverImage({required this.song, required this.size});

  Widget _getImage(BuildContext context) {
    if (song.coverArt == null) {
      if (song.serverId != -1) {
        var songProvider = context.read<SongProvider>();
        return songProvider.getCoverArt(song.serverId);
      }
      return Container(
        color: Colors.black,
        child: Icon(
          FluentIcons.music,
          color: Colors.white.withValues(alpha: 0.25),
          size: 64,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          fit: BoxFit.cover,
          image: MemoryImage(song.coverArt!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.indigo.withValues(alpha: 0.3),
      child: _getImage(context),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headphones, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'Start listening to get recommendations',
              style: TextStyle(color: Colors.white38, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
