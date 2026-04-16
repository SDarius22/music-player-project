import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_tile.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/route_builder.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

class HomeScreen extends StatefulWidget {
  static Route<dynamic> route() {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => const HomeScreen(),
      settings: const RouteSettings(name: "/home"),
    );
  }

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Song>> _quickDialFuture;
  late Future<List<Song>> _recommendationsFuture;
  late Future<List<Song>> _rediscoverFuture;
  late final AbstractAppStateProvider _appStateProvider;

  @override
  void initState() {
    super.initState();
    _appStateProvider = context.read<AbstractAppStateProvider>();
    _appStateProvider.refreshRequestNotifier.addListener(_onGlobalRefresh);
    _resetSectionFutures();
  }

  @override
  void dispose() {
    _appStateProvider.refreshRequestNotifier.removeListener(_onGlobalRefresh);
    super.dispose();
  }

  void _onGlobalRefresh() {
    if (!mounted) return;
    _refreshHomeSections();
  }

  void _resetSectionFutures() {
    final songProvider = context.read<SongProvider>();
    _quickDialFuture = songProvider.fetchJumpBackSongs();
    _recommendationsFuture = songProvider.fetchRecommendedSongs();
    _rediscoverFuture = songProvider.fetchRediscoverSongs();
  }

  Future<void> _refreshHomeSections() async {
    setState(_resetSectionFutures);
    await Future.wait([
      _quickDialFuture,
      _recommendationsFuture,
      _rediscoverFuture,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final theme = MusicPlayerTheme.getTheme();

    return GlassScaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          height: kToolbarHeight,
          padding: EdgeInsets.symmetric(horizontal: hPadFor(context)),
          margin: EdgeInsets.symmetric(vertical: width * 0.005),
          alignment: Alignment.centerLeft,
          child: Selector<UserProvider, String>(
            selector: (_, p) => p.currentUser?.email ?? '',
            builder: (context, email, _) {
              final name = email.isNotEmpty ? email.split('@').first : '';
              return Text(
                name.isNotEmpty ? '${_greeting()}, $name!' : _greeting(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHomeSections,
        color: Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSectionFutureSliver(
              future: _quickDialFuture,
              title: 'Jump back in',
              subtitle: 'Your recent tracks',
              cardStyle: _CardStyle.wide,
            ),
            _buildSectionFutureSliver(
              future: _recommendationsFuture,
              title: 'Recommended for you',
              subtitle: 'Based on your listening',
              cardStyle: _CardStyle.square,
            ),
            _buildSectionFutureSliver(
              future: _rediscoverFuture,
              title: 'Rediscover',
              subtitle: "Songs you haven't heard in a while",
              cardStyle: _CardStyle.square,
            ),
            _buildEmptyStateFutureSliver(),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildDesktopRail(
    BuildContext context,
    List<Song> songs,
    _CardStyle cardStyle,
    double width,
    ThemeData theme,
  ) {
    final wide = cardStyle == _CardStyle.wide;
    final cardHeight = wide ? width * 0.08 : width * 0.14;

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
          itemBuilder: (context, i) {
            return CustomGridTile(
              onTap:
                  () => context.read<AudioProvider>().setQueueAndPlay(
                    songs,
                    songs[i],
                  ),
              onLongPress: () {},
              entity: songs[i],
              wide: wide,
              isSelected: false,
              mainAction: Icon(
                FluentIcons.play,
                color: Colors.white.withValues(alpha: 0.8),
                size: 30,
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildSectionSlivers(
    BuildContext context, {
    required String title,
    required String subtitle,
    required AsyncSnapshot<List<Song>> snapshot,
    required _CardStyle cardStyle,
  }) {
    final width = MediaQuery.of(context).size.width;
    final theme = MusicPlayerTheme.getTheme();
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    final slivers = <Widget>[
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: hPadFor(context)),
        sliver: SliverToBoxAdapter(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: hPadFor(context)),
        sliver: SliverToBoxAdapter(
          child: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: width * 0.01)),
    ];

    if (snapshot.connectionState == ConnectionState.waiting) {
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPadFor(context)),
          sliver: const SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
      return slivers;
    }

    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPadFor(context)),
          sliver: SliverToBoxAdapter(child: _buildEmptyState()),
        ),
      );
      return slivers;
    }

    final songs = snapshot.data!;

    final capped =
        cardStyle == _CardStyle.wide
            ? songs.take(6).toList()
            : songs.take(9).toList();

    if (isMobile && cardStyle == _CardStyle.wide) {
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            hPadFor(context),
            width * 0.04,
            hPadFor(context),
            0,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate((context, i) {
              return CustomGridTile(
                onTap:
                    () => context.read<AudioProvider>().setQueueAndPlay(
                      songs,
                      capped[i],
                    ),
                onLongPress: () {},
                entity: capped[i],
                isSelected: false,
                wide: true,
              );
            }, childCount: capped.length),
          ),
        ),
      );
    } else if (isMobile) {
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPadFor(context)),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate((context, i) {
              return CustomGridTile(
                onTap:
                    () => context.read<AudioProvider>().setQueueAndPlay(
                      songs,
                      capped[i],
                    ),
                onLongPress: () {},
                entity: capped[i],
                isSelected: false,
                mainAction: Icon(
                  FluentIcons.play,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 30,
                ),
              );
            }, childCount: capped.length),
          ),
        ),
      );
    } else {
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPadFor(context)),
          sliver: SliverToBoxAdapter(
            child: _buildDesktopRail(context, songs, cardStyle, width, theme),
          ),
        ),
      );
    }

    slivers.add(
      SliverToBoxAdapter(
        child: SizedBox(height: isMobile ? width * 0.075 : width * 0.02),
      ),
    );
    return slivers;
  }

  Widget _buildSectionFutureSliver({
    required Future<List<Song>> future,
    required String title,
    required String subtitle,
    required _CardStyle cardStyle,
  }) {
    return FutureBuilder<List<Song>>(
      future: future,
      builder: (context, snapshot) {
        return SliverMainAxisGroup(
          slivers: _buildSectionSlivers(
            context,
            title: title,
            subtitle: subtitle,
            snapshot: snapshot,
            cardStyle: cardStyle,
          ),
        );
      },
    );
  }

  Widget _buildEmptyStateFutureSliver() {
    return FutureBuilder<List<List<Song>>>(
      future: Future.wait([
        _quickDialFuture,
        _recommendationsFuture,
        _rediscoverFuture,
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final allEmpty = snapshot.data!.every((section) => section.isEmpty);
        if (!allEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPadFor(context)),
          sliver: SliverToBoxAdapter(child: _buildEmptyState()),
        );
      },
    );
  }

  double hPadFor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    return isMobile ? width * 0.04 : width * 0.01;
  }

  Widget _buildEmptyState() {
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

enum _CardStyle { square, wide }
