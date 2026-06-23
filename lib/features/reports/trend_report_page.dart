import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format_utils.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';

class TrendReportPage extends ConsumerStatefulWidget {
  const TrendReportPage({super.key});

  @override
  ConsumerState<TrendReportPage> createState() => _TrendReportPageState();
}

class _TrendReportPageState extends ConsumerState<TrendReportPage> {
  final _db = AppDatabase();
  bool _loading = true;
  List<_TrendPoint> _points = [];

  // 内容健康度
  double _likePlayRatio = 0.0;
  List<_VideoInteraction> _recent5Interactions = [];
  Map<int, double> _hourBuckets = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final allWithMetrics = await _db.getAllVideosWithMetrics();
      final points = <_TrendPoint>[];
      int totalPlays = 0, totalLikes = 0;

      for (final v in allWithMetrics) {
        final plays = (v['play_count'] as int?) ?? 0;
        final likes = (v['like_count'] as int?) ?? 0;
        totalPlays += plays;
        totalLikes += likes;

        final ct = v['create_time'] as int?;
        if (ct != null && ct > 0) {
          points.add(_TrendPoint(
            date: DateTime.fromMillisecondsSinceEpoch(ct * 1000),
            plays: plays,
            likes: likes,
          ));
        }
      }

      points.sort((a, b) => a.date.compareTo(b.date));

      // 内容健康度 - 点赞播放比
      final ratio = totalPlays > 0 ? (totalLikes / totalPlays * 100) : 0.0;

      // 最近5条互动率
      final sorted = List<Map<String, dynamic>>.from(allWithMetrics);
      sorted.sort((a, b) =>
          ((b['create_time'] as int?) ?? 0).compareTo((a['create_time'] as int?) ?? 0));
      final recent5 = sorted.take(5).toList();
      final interactions = recent5.map((v) {
        final p = (v['play_count'] as int?) ?? 0;
        final l = (v['like_count'] as int?) ?? 0;
        final c = (v['comment_count'] as int?) ?? 0;
        final s = (v['share_count'] as int?) ?? 0;
        final rate = p > 0 ? ((l + c + s) / p * 100) : 0.0;
        return _VideoInteraction(
            title: v['title'] as String? ?? '',
            rate: rate,
            plays: p);
      }).toList();

      // 最佳发布时间
      final hourMap = <int, List<double>>{};
      for (final vm in allWithMetrics) {
        final ct = vm['create_time'] as int?;
        if (ct == null || ct <= 0) continue;
        final hour = DateTime.fromMillisecondsSinceEpoch(ct * 1000).hour;
        final plays = (vm['play_count'] as int?) ?? 0;
        hourMap.putIfAbsent(hour, () => []);
        hourMap[hour]!.add(plays.toDouble());
      }
      final hourBuckets = <int, double>{};
      for (final e in hourMap.entries) {
        final avg = e.value.fold<double>(0, (s, v) => s + v) / e.value.length;
        hourBuckets[e.key] = avg;
      }

      if (!mounted) return;
      setState(() {
        _points = points;
        _likePlayRatio = ratio;
        _recent5Interactions = interactions;
        _hourBuckets = hourBuckets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('播放趋势报告')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_points.isEmpty) {
      return Center(
          child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])));
    }

    final last7 = _points.length >= 7 ? _points.sublist(_points.length - 7) : _points;
    final last30 = _points.length >= 30 ? _points.sublist(_points.length - 30) : _points;
    final last7Plays = last7.fold<int>(0, (s, p) => s + p.plays);
    final last30Plays = last30.fold<int>(0, (s, p) => s + p.plays);
    String? peakDate;
    int peakPlays = 0;
    for (final p in _points) {
      if (p.plays > peakPlays) {
        peakPlays = p.plays;
        peakDate = '${p.date.year}-${p.date.month.toString().padLeft(2, '0')}-${p.date.day.toString().padLeft(2, '0')}';
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildChartCard(),
        const SizedBox(height: 16),
        _buildSummaryCard(last7Plays, last30Plays, peakDate),
        const SizedBox(height: 16),
        _buildContentHealthCard(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildChartCard() {
    if (_points.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
              child:
                  Text('数据点不足，需要至少 2 条视频', style: TextStyle(color: Colors.grey[500]))),
        ),
      );
    }

    final maxPlays = _points.fold<int>(0, (s, p) => p.plays > s ? p.plays : s);
    final maxLikes = _points.fold<int>(0, (s, p) => p.likes > s ? p.likes : s);
    final globalMax = (maxPlays > maxLikes ? maxPlays : maxLikes).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('播放量 & 点赞量趋势',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (globalMax / 4).clamp(1, double.infinity),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.12),
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (_points.length / 4).ceilToDouble().clamp(1, 100),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < _points.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${_points[idx].date.month}/${_points[idx].date.day}',
                                style: TextStyle(
                                    fontSize: 9, color: Colors.grey[500]),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(formatCount(value.toInt()),
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey[500]));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _points
                          .asMap()
                          .entries
                          .map((e) =>
                              FlSpot(e.key.toDouble(), e.value.plays.toDouble()))
                          .toList(),
                      isCurved: true,
                      color: AppTheme.douyinRed,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: _points.length <= 30,
                        getDotPainter: (spot, _, __, ___) =>
                            FlDotCirclePainter(
                                radius: 3,
                                color: AppTheme.douyinRed,
                                strokeWidth: 0),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.douyinRed.withValues(alpha: 0.06),
                      ),
                    ),
                    LineChartBarData(
                      spots: _points
                          .asMap()
                          .entries
                          .map((e) =>
                              FlSpot(e.key.toDouble(), e.value.likes.toDouble()))
                          .toList(),
                      isCurved: true,
                      color: AppTheme.douyinCyan,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: _points.length <= 30,
                        getDotPainter: (spot, _, __, ___) =>
                            FlDotCirclePainter(
                                radius: 3,
                                color: AppTheme.douyinCyan,
                                strokeWidth: 0),
                      ),
                    ),
                  ],
                  minY: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(AppTheme.douyinRed, '播放量'),
                const SizedBox(width: 20),
                _legendDot(AppTheme.douyinCyan, '点赞量'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildSummaryCard(int last7Plays, int last30Plays, String? peakDate) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('汇总统计',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _summaryRow('最近 7 天播放', formatCount(last7Plays)),
            _summaryRow('最近 30 天播放', formatCount(last30Plays)),
            _summaryRow('最高播放日',
                peakDate ?? '--'),
            _summaryRow('总视频数', '${_points.length} 条'),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ======== 内容健康度面板 ========
  Widget _buildContentHealthCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('内容健康度',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            // 点赞播放比
            _healthMetricRow(
                '点赞播放比',
                '${_likePlayRatio.toStringAsFixed(2)}%',
                '总赞 / 总播放 × 100',
                AppTheme.douyinRed),
            const SizedBox(height: 12),
            // 最近5条互动率
            const Text('最近 5 条视频互动率变化',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ..._recent5Interactions.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              IconData trendIcon = Icons.remove;
              Color trendColor = Colors.grey;
              if (_recent5Interactions.length > 1 && idx < _recent5Interactions.length - 1) {
                final prev = _recent5Interactions[idx + 1].rate;
                if (item.rate > prev) {
                  trendIcon = Icons.arrow_upward;
                  trendColor = AppTheme.accentGreen;
                } else if (item.rate < prev) {
                  trendIcon = Icons.arrow_downward;
                  trendColor = AppTheme.douyinRed;
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(trendIcon, size: 14, color: trendColor),
                    const SizedBox(width: 4),
                    Text('${item.rate.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: trendColor)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            // 最佳发布时间分析
            const Text('最佳发布时间分析',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _buildBestTimeSection(),
          ],
        ),
      ),
    );
  }

  Widget _healthMetricRow(
      String label, String value, String subtitle, Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ),
      ],
    );
  }

  Widget _buildBestTimeSection() {
    if (_hourBuckets.isEmpty) {
      return Text('暂无时间分布数据', style: TextStyle(color: Colors.grey[500], fontSize: 12));
    }

    final sorted = _hourBuckets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '各小时段平均播放量 Top 3：',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        const SizedBox(height: 6),
        ...top3.asMap().entries.map((e) {
          final rank = e.key + 1;
          final hour = e.value.key;
          final avgPlay = e.value.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? AppTheme.accentAmber.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$rank',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: rank == 1
                              ? AppTheme.accentAmber
                              : Colors.grey[600])),
                ),
                const SizedBox(width: 8),
                Text(
                  '${hour.toString().padLeft(2, '0')}:00 - avg ${formatCount(avgPlay.round())} 播放',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TrendPoint {
  final DateTime date;
  final int plays;
  final int likes;
  _TrendPoint({required this.date, required this.plays, required this.likes});
}

class _VideoInteraction {
  final String title;
  final double rate;
  final int plays;
  _VideoInteraction({required this.title, required this.rate, required this.plays});
}
