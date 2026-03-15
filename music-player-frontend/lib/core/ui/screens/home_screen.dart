import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/home_provider.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:provider/provider.dart';

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
    final scaler = context.read<Scaler>();
    final width = MediaQuery.of(context).size.width;
    final theme = MusicPlayerTheme.getTheme(context, scaler);

    return GlassScaffold(
      body: RefreshIndicator(
        onRefresh: () => context.read<HomeProvider>().refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  width * 0.02,
                  width * 0.02,
                  width * 0.02,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Selector<UserProvider, String>(
                      selector: (_, p) => p.currentUser?.email ?? '',
                      builder: (context, email, _) {
                        final name =
                            email.isNotEmpty ? email.split('@').first : '';
                        return Text(
                          name.isNotEmpty
                              ? '${_greeting()}, $name'
                              : _greeting(),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: width * 0.04),
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

                return SliverList(
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
                        subtitle: 'Songs you haven\'t heard in a while',
                        songs: home.forgottenFavourites,
                        cardStyle: _CardStyle.square,
                      ),
                    if (!home.loading &&
                        home.quickDial.isEmpty &&
                        home.recommendations.isEmpty &&
                        home.forgottenFavourites.isEmpty)
                      _EmptyState(),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                  ]),
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
    final scaler = context.read<Scaler>();
    final width = MediaQuery.of(context).size.width;
    final theme = MusicPlayerTheme.getTheme(context, scaler);

    final cardWidth =
        cardStyle == _CardStyle.wide ? width * 0.22 : width * 0.14;
    final cardHeight =
        cardStyle == _CardStyle.wide ? width * 0.08 : width * 0.14;

    return Padding(
      padding: EdgeInsets.only(bottom: width * 0.03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.02),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
                ),
                SizedBox(height: width * 0.01),
              ],
            ),
          ),
          SizedBox(
            height: cardHeight + width * 0.06,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: width * 0.02),
              itemCount: songs.length,
              separatorBuilder: (_, __) => SizedBox(width: width * 0.01),
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
        ],
      ),
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
    final scaler = context.read<Scaler>();
    final theme = MusicPlayerTheme.getTheme(context, scaler);

    return GestureDetector(
      onTap: () {
        context.read<AudioProvider>().setQueueAndPlay(songs, song);
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
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(10),
              ),
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

  @override
  Widget build(BuildContext context) {
    return Image(
      image: MemoryImage(song.coverArt),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder:
          (_, __, ___) => Container(
            width: size,
            height: size,
            color: Colors.indigo.withValues(alpha: 0.3),
            child: const Icon(Icons.music_note, color: Colors.white54),
          ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headphones, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
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
