import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/models/chunk_stat_record.dart';
import 'package:music_player_frontend/core/services/rest_clients/statistics_rest_service.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:provider/provider.dart';

class StatisticsScreen extends StatefulWidget {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/statistics'),
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: const StatisticsScreen(),
        );
      },
    );
  }

  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<List<ChunkStatRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<StatisticsRestService>().getStatistics();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = context.read<StatisticsRestService>().getStatistics();
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
        child: FutureBuilder<List<ChunkStatRecord>>(
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
                            Icons.error_outline,
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
                          'Chunk Delivery Statistics',
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
                            Icons.bar_chart,
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
                        final r = records[records.length - 1 - i];
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
  final List<ChunkStatRecord> records;
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
    final avgP2p =
        records.isEmpty
            ? 0.0
            : records.fold(0.0, (s, r) => s + r.p2pPercentage) / records.length;

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
      child: Row(
        children: [
          _StatBadge(
            label: 'Avg P2P',
            value: '${avgP2p.toStringAsFixed(1)}%',
            color: Colors.greenAccent,
          ),
          _StatBadge(
            label: 'P2P Chunks',
            value: totalP2p.toString(),
            color: Colors.blueAccent,
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
    return Expanded(
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
  final ChunkStatRecord record;
  final ThemeData theme;
  final double width;

  const _StatRow({
    required this.record,
    required this.theme,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final pct = record.p2pPercentage;
    final barColor =
        pct >= 70
            ? Colors.greenAccent
            : pct >= 40
            ? Colors.orangeAccent
            : Colors.redAccent;

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
                  record.songName ?? 'Unknown song',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}% P2P',
                style: TextStyle(
                  color: barColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          SizedBox(height: width * 0.008),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
          SizedBox(height: width * 0.008),
          Row(
            children: [
              Text(
                '${record.p2pChunks} P2P · ${record.serverChunks} server · ${record.totalChunks} total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white38,
                ),
              ),
              const Spacer(),
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
}
