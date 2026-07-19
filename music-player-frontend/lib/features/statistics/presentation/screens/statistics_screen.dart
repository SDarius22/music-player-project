import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/core/services/chunk_stats_service.dart';
import 'package:music_player_frontend/app/theme/music_player_theme.dart';
import 'package:music_player_frontend/shared/presentation/scaffolds/glass_scaffold.dart';
import 'package:fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

import 'package:music_player_frontend/shared/presentation/navigation/route_builder.dart';

class StatisticsScreen extends StatefulWidget {
  static Route<dynamic> route() {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => const StatisticsScreen(),
      settings: const RouteSettings(name: "/statistics"),
    );
  }

  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<List<ChunkStat>> _future;
  late final AbstractAppStateProvider _appStateProvider;

  @override
  void initState() {
    super.initState();
    _appStateProvider = context.read<AbstractAppStateProvider>();
    _appStateProvider.refreshRequestNotifier.addListener(_onGlobalRefresh);
    _future = ChunkStatsService.instance.getStatistics();
  }

  @override
  void dispose() {
    _appStateProvider.refreshRequestNotifier.removeListener(_onGlobalRefresh);
    super.dispose();
  }

  void _onGlobalRefresh() {
    if (!mounted) return;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ChunkStatsService.instance.getStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final theme = MusicPlayerTheme.getTheme();

    return GlassScaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.white,
        child: FutureBuilder<List<ChunkStat>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            FluentIcons.error,
                            color: Colors.white38,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load statistics',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            final records = snapshot.data ?? [];
            debugPrint('Loaded ${records.length} statistics records');

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      width * 0.02,
                      width * 0.02,
                      width * 0.02,
                      width * 0.02,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server Offload Statistics',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: width * 0.005),
                        Text(
                          '${records.length} session${records.length == 1 ? '' : 's'} recorded',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                        if (records.isNotEmpty) ...[
                          SizedBox(height: width * 0.02),
                          _SummaryCard(
                            records: records,
                            width: width,
                            theme: theme,
                          ),
                        ],
                        SizedBox(height: width * 0.02),
                      ],
                    ),
                  ),
                ),
                if (records.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            FluentIcons.barChart,
                            color: Colors.white24,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No statistics recorded yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final r = records[i];
                        return Padding(
                          padding: EdgeInsets.only(bottom: width * 0.01),
                          child: _StatRow(
                            record: r,
                            theme: theme,
                            width: width,
                          ),
                        );
                      }, childCount: records.length),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.15,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<ChunkStat> records;
  final double width;
  final ThemeData theme;

  const _SummaryCard({
    required this.records,
    required this.width,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final totalChunks = records.fold(0, (s, r) => s + r.totalChunks);
    final totalP2p = records.fold(0, (s, r) => s + r.p2pChunks);
    final totalCached = records.fold(0, (s, r) => s + r.localCachedChunks);
    final totalLocal = records.fold(0, (s, r) => s + r.localChunks);
    final totalOffloaded = records.fold(
      0,
      (sum, record) => sum + record.serverOffloadedChunks,
    );
    final serverOffload =
        totalChunks == 0 ? 0.0 : totalOffloaded / totalChunks * 100;

    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.indigo.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(width * 0.02),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        children: [
          _StatBadge(
            label: 'Server Offload',
            value: '${serverOffload.toStringAsFixed(1)}%',
            color: Colors.greenAccent,
          ),
          _StatBadge(
            label: 'P2P Chunks',
            value: totalP2p.toString(),
            color: Colors.blueAccent,
          ),
          _StatBadge(
            label: 'Cached Chunks',
            value: totalCached.toString(),
            color: Colors.amberAccent,
          ),
          _StatBadge(
            label: 'Local Files',
            value: totalLocal.toString(),
            color: Colors.purpleAccent,
          ),
          _StatBadge(
            label: 'Total Chunks',
            value: totalChunks.toString(),
            color: Colors.white70,
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final ChunkStat record;
  final ThemeData theme;
  final double width;

  const _StatRow({
    required this.record,
    required this.theme,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isLocalFile = record.isLocalFilePlayback;

    final ts = record.timestamp.toLocal();
    final dateStr =
        '${ts.year}-${ts.month.toString().padLeft(2, '0')}-'
        '${ts.day.toString().padLeft(2, '0')} '
        '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      padding: EdgeInsets.all(width * 0.015),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.songName.isEmpty ? 'Unknown song' : record.songName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isLocalFile)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Local',
                    style: TextStyle(
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                Text(
                  '${record.serverOffloadPercentage.toStringAsFixed(1)}% offloaded',
                  style: TextStyle(
                    color: _offloadColor(record.serverOffloadPercentage),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          if (!isLocalFile) ...[
            SizedBox(height: width * 0.008),
            _DeliveryBar(record: record, width: width),
          ],
          SizedBox(height: width * 0.008),
          Row(
            children: [
              Expanded(
                child: Text(
                  isLocalFile
                      ? 'Played from local file'
                      : _chunkBreakdown(record),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                  ),
                ),
              ),
              Text(
                dateStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _offloadColor(double pct) {
    if (pct >= 70) return Colors.greenAccent;
    if (pct >= 40) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _chunkBreakdown(ChunkStat r) {
    final parts = <String>[];
    if (r.p2pChunks > 0) parts.add('${r.p2pChunks} P2P');
    if (r.serverChunks > 0) parts.add('${r.serverChunks} server');
    if (r.localCachedChunks > 0) parts.add('${r.localCachedChunks} cached');
    if (r.localChunks > 0) parts.add('${r.localChunks} local');
    parts.add('${r.totalChunks} total');
    return parts.join(' · ');
  }
}

class _DeliveryBar extends StatelessWidget {
  final ChunkStat record;
  final double width;

  const _DeliveryBar({required this.record, required this.width});

  @override
  Widget build(BuildContext context) {
    final total = record.totalChunks;
    if (total == 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: const LinearProgressIndicator(
          value: 0,
          backgroundColor: Colors.white12,
          minHeight: 6,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            if (record.p2pChunks > 0)
              Flexible(
                flex: record.p2pChunks,
                child: Container(color: Colors.greenAccent),
              ),
            if (record.localCachedChunks > 0)
              Flexible(
                flex: record.localCachedChunks,
                child: Container(color: Colors.amberAccent),
              ),
            if (record.localChunks > 0)
              Flexible(
                flex: record.localChunks,
                child: Container(color: Colors.purpleAccent),
              ),
            if (record.serverChunks > 0)
              Flexible(
                flex: record.serverChunks,
                child: Container(
                  color: Colors.redAccent.withValues(alpha: 0.7),
                ),
              ),
            // Fill remaining with background if needed
            if (record.p2pChunks == 0 &&
                record.localCachedChunks == 0 &&
                record.localChunks == 0 &&
                record.serverChunks == 0)
              Flexible(flex: 1, child: Container(color: Colors.white12)),
          ],
        ),
      ),
    );
  }
}
