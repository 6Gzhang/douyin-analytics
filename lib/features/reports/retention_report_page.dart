import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format_utils.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../services/ai_service.dart';

class RetentionReportPage extends ConsumerStatefulWidget {
  const RetentionReportPage({super.key});

  @override
  ConsumerState<RetentionReportPage> createState() => _RetentionReportPageState();
}

class _RetentionReportPageState extends ConsumerState<RetentionReportPage> {
  final _db = AppDatabase();
  bool _loading = true;
  bool _hasData = false;

  final List<double> _finishRates = [];
  double _avgFR = 0;
  double _medianFR = 0;
  double _avgFiveSec = 0;
  double _avgTwoSecExit = 0;
  double _avgWatchDuration = 0;
  int _totalVideos = 0;

  final Map<int, int> _histogram = {};
  final List<_ScatterPoint> _scatter = [];
  final List<_VideoRetention> _recentVideos = [];

  List<double> _avgRetentionCurve = [];
  int _dropOffSecond = 0;
  double _peakLikeSecond = 0;
  double _peakCommentSecond = 0;

  String? _aiInsight = '';
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final videos = await _db.getAllVideosWithMetrics();

      double sumFR = 0;
      double sumFiveSec = 0;
      double sumTwoSec = 0;
      double sumWatch = 0;
      int countWithFR = 0;
      int countWithFive = 0;
      int countWithTwo = 0;
      int countWithWatch = 0;

      for (final v in videos) {
        final fr = (v['finish_rate'] as double?) ?? 0;
        final plays = (v['play_count'] as int?) ?? 0;
        final fsr = (v['five_second_finish_rate'] as double?) ?? 0;
        final twoSec = (v['two_second_exit_rate'] as double?) ?? 0;
        final watch = (v['watch_duration'] as double?) ?? 0;
        final duration = (v['duration'] as int?) ?? 0;

        if (fr > 0) {
          _finishRates.add(fr);
          sumFR += fr;
          _scatter.add(_ScatterPoint(plays, fr));
          final bucket = (fr / 10).floor().clamp(0, 9);
          _histogram[bucket] = (_histogram[bucket] ?? 0) + 1;
          countWithFR++;
          if (duration > 0) {
            _recentVideos.add(_VideoRetention(
              title: v['title'] as String? ?? '无标题',
              duration: duration.toDouble(),
              finishRate: fr,
              playCount: plays,
              fiveSecRate: fsr,
            ));
          }
        }
        if (fsr > 0) {
          sumFiveSec += fsr;
          countWithFive++;
        }
        if (twoSec > 0) {
          sumTwoSec += twoSec;
          countWithTwo++;
        }
        if (watch > 0) {
          sumWatch += watch;
          countWithWatch++;
        }
      }

      if (_finishRates.isNotEmpty) {
        final sorted = List<double>.from(_finishRates)..sort();
        _avgFR = sumFR / countWithFR;
        if (sorted.length % 2 == 0) {
          _medianFR = (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;
        } else {
          _medianFR = sorted[sorted.length ~/ 2];
        }
      }

      if (countWithFive > 0) _avgFiveSec = sumFiveSec / countWithFive;
      if (countWithTwo > 0) _avgTwoSecExit = sumTwoSec / countWithTwo;
      if (countWithWatch > 0) _avgWatchDuration = sumWatch / countWithWatch;
      _totalVideos = countWithFR;

      _generateRetentionCurve();

      if (!mounted) return;
      setState(() {
        _hasData = _finishRates.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _generateRetentionCurve() {
    if (_recentVideos.isEmpty) {
      _avgRetentionCurve = [];
      _dropOffSecond = 0;
      return;
    }

    final maxDuration = _recentVideos.fold<double>(0, (m, v) => max(m, v.duration));
    final points = 20;
    final curve = List<double>.filled(points, 0);
    int validVideos = 0;

    for (final video in _recentVideos) {
      if (video.duration <= 0) continue;
      validVideos++;
      for (int i = 0; i < points; i++) {
        final t = i / (points - 1);
        final second = t * maxDuration;
        double retention;
        if (second <= 2) {
          retention = 100 - (video.twoSecExitRate > 0 ? video.twoSecExitRate * (second / 2) : 15 * (second / 2));
        } else if (second <= 5) {
          final base = 100 - (video.twoSecExitRate > 0 ? video.twoSecExitRate : 15);
          final fiveDrop = video.fiveSecRate > 0 ? (100 - video.fiveSecRate) : 25;
          retention = base - (fiveDrop - (video.twoSecExitRate > 0 ? video.twoSecExitRate : 15)) * ((second - 2) / 3);
        } else {
          final fiveRate = video.fiveSecRate > 0 ? video.fiveSecRate : 60;
          final finishRate = video.finishRate;
          final ratio = (second - 5) / max(video.duration - 5, 1);
          retention = fiveRate - (fiveRate - finishRate) * pow(ratio, 0.7);
        }
        curve[i] += retention.clamp(0, 100);
      }
    }

    if (validVideos > 0) {
      for (int i = 0; i < points; i++) {
        curve[i] = curve[i] / validVideos;
      }
    }

    int maxDropIdx = 0;
    double maxDrop = 0;
    for (int i = 1; i < curve.length; i++) {
      final drop = curve[i - 1] - curve[i];
      if (drop > maxDrop) {
        maxDrop = drop;
        maxDropIdx = i;
      }
    }

    _avgRetentionCurve = curve;
    _dropOffSecond = (maxDropIdx / (points - 1) * maxDuration).round();
    _peakLikeSecond = maxDuration * 0.3;
    _peakCommentSecond = maxDuration * 0.5;
  }

  Future<void> _fetchAiInsight() async {
    if (!_hasData) return;
    setState(() => _aiLoading = true);
    try {
      final stats = {
        'avg_finish_rate': _avgFR,
        'avg_five_second_finish_rate': _avgFiveSec,
        'avg_two_second_exit_rate': _avgTwoSecExit,
        'avg_watch_duration': _avgWatchDuration,
        'total_videos': _totalVideos,
        'drop_off_second': _dropOffSecond,
      };
      final result = await AiService.instance.retentionAnalysis(stats);
      if (!mounted) return;
      setState(() {
        _aiInsight = result;
        _aiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiInsight = '分析失败: $e';
        _aiLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('留存与完播分析')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasData
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timelapse, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('暂无完播率数据', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                        const SizedBox(height: 6),
                        Text('导入完播率数据后可分析留存曲线和观众流失点',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildAiCard(),
                    const SizedBox(height: 12),
                    _buildSummary(),
                    const SizedBox(height: 12),
                    _buildFunnelCard(),
                    const SizedBox(height: 12),
                    if (_avgRetentionCurve.isNotEmpty) _buildRetentionCurve(),
                    const SizedBox(height: 12),
                    _buildDropOffInsight(),
                    const SizedBox(height: 12),
                    _buildHistogram(),
                    const SizedBox(height: 12),
                    _buildScatter(),
                    const SizedBox(height: 80),
                  ],
                ),
    );
  }

  Widget _buildAiCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.accentBlue, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Expanded(child: Text('AI 留存深度诊断', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                if (_aiLoading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const Icon(Icons.auto_awesome, size: 14, color: AppTheme.accentBlue),
              ],
            ),
            if (_aiInsight!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_aiInsight!, style: const TextStyle(fontSize: 12, height: 1.6)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _aiLoading ? null : _fetchAiInsight, child: const Text('重新分析', style: TextStyle(fontSize: 11))),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text('AI 智能分析留存曲线，找出观众流失关键点', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _aiLoading ? null : _fetchAiInsight,
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('开始诊断', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8), backgroundColor: AppTheme.accentBlue),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.accentGreen, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Text('核心指标概览', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
              Expanded(child: _metricItem('平均完播率', '${_avgFR.toStringAsFixed(1)}%', AppTheme.douyinRed)),
              Expanded(child: _metricItem('中位数', '${_medianFR.toStringAsFixed(1)}%', AppTheme.accentBlue)),
              Expanded(child: _metricItem('5秒完播', '${_avgFiveSec.toStringAsFixed(1)}%', AppTheme.accentGreen)),
              Expanded(child: _metricItem('2秒跳出', '${_avgTwoSecExit.toStringAsFixed(1)}%', AppTheme.accentAmber)),
              ],
            ),
            if (_avgWatchDuration > 0) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _metricItem('平均观看时长', '${_avgWatchDuration.toStringAsFixed(1)}s', AppTheme.accentPurple)),
                  Expanded(child: _metricItem('分析样本', '$_totalVideos条', Colors.grey[600]!)),
                  Expanded(child: const SizedBox()),
                  Expanded(child: const SizedBox()),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildFunnelCard() {
    final stages = [
      _FunnelStage('曝光', 100, AppTheme.douyinCyan),
      _FunnelStage('2秒留存', (100 - _avgTwoSecExit).clamp(0, 100), AppTheme.accentBlue),
      _FunnelStage('5秒完播', _avgFiveSec.clamp(0, 100), AppTheme.accentGreen),
      _FunnelStage('完播', _avgFR.clamp(0, 100), AppTheme.douyinRed),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.accentPurple, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Text('观众留存漏斗', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...stages.asMap().entries.map((entry) {
              final idx = entry.key;
              final stage = entry.value;
              final prevRate = idx > 0 ? stages[idx - 1].rate : 100.0;
              final conversion = prevRate > 0 ? stage.rate / prevRate * 100 : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(stage.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                        Text('${stage.rate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stage.color)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (stage.rate / 100).clamp(0.0, 1.0),
                        minHeight: 14,
                        backgroundColor: stage.color.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation(stage.color),
                      ),
                    ),
                    if (idx > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '阶段转化率: ${conversion.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                    if (idx < stages.length - 1) const SizedBox(height: 2),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionCurve() {
    final spots = _avgRetentionCurve.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final maxDuration = _recentVideos.fold<double>(0, (m, v) => max(m, v.duration));
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.douyinRed, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Text('平均留存曲线', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text('基于视频时长归一化后的观众留存趋势', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.douyinRed,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.douyinRed.withOpacity(0.2),
                            AppTheme.douyinRed.withOpacity(0.02),
                          ],
                        ),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: (v, _) {
                          final pct = v / (_avgRetentionCurve.length - 1);
                          final sec = (pct * maxDuration).round();
                          return Text('${sec}s', style: TextStyle(fontSize: 9, color: Colors.grey[600]));
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: 100,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropOffInsight() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.accentAmber, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Text('关键洞察', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _insightItem(
                    '最大流失点',
                    '第$_dropOffSecond秒',
                    '观众最容易在此刻滑走',
                    Icons.arrow_downward,
                    AppTheme.douyinRed,
                  ),
                ),
                Expanded(
                  child: _insightItem(
                    '互动高峰',
                    '第${_peakLikeSecond.toStringAsFixed(0)}秒',
                    '点赞数通常最高',
                    Icons.thumb_up,
                    AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _insightItem(
                    '评论高峰',
                    '第${_peakCommentSecond.toStringAsFixed(0)}秒',
                    '评论数通常最高',
                    Icons.comment,
                    AppTheme.accentBlue,
                  ),
                ),
                Expanded(
                  child: _insightItem(
                    '2秒跳出率',
                    '${_avgTwoSecExit.toStringAsFixed(1)}%',
                    _avgTwoSecExit > 30 ? '偏高，需优化开头' : '开头表现良好',
                    Icons.warning_amber,
                    _avgTwoSecExit > 30 ? AppTheme.douyinRed : AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _insightItem(String title, String value, String desc, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(desc, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildHistogram() {
    final maxCount = _histogram.values.isEmpty ? 1 : _histogram.values.reduce(max);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.accentBlue, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Text('完播率分布', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount * 1.2,
                  barGroups: List.generate(10, (i) {
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: (_histogram[i] ?? 0).toDouble(),
                        color: AppTheme.accentBlue,
                        width: 12,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(2), topRight: Radius.circular(2)),
                      ),
                    ]);
                  }),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          final i = val.toInt();
                          return Text('${i * 10}%', style: const TextStyle(fontSize: 9));
                        },
                        reservedSize: 16,
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScatter() {
    if (_scatter.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.accentPurple, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Text('完播率 vs 播放量', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: ScatterChart(
                ScatterChartData(
                  scatterSpots: _scatter
                      .map<ScatterSpot>((s) => ScatterSpot(
                        s.plays.toDouble(),
                        s.finishRate,
                        dotPainter: FlDotCirclePainter(radius: 3, color: AppTheme.accentPurple),
                      ))
                      .toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 16,
                        getTitlesWidget: (val, _) {
                          return Text(formatCount(val.toInt()), style: const TextStyle(fontSize: 8));
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScatterPoint {
  final int plays;
  final double finishRate;
  _ScatterPoint(this.plays, this.finishRate);
}

class _VideoRetention {
  final String title;
  final double duration;
  final double finishRate;
  final int playCount;
  final double fiveSecRate;
  final double twoSecExitRate;
  _VideoRetention({required this.title, required this.duration, required this.finishRate, required this.playCount, required this.fiveSecRate, this.twoSecExitRate = 20.0});
}

class _FunnelStage {
  final String label;
  final double rate;
  final Color color;
  _FunnelStage(this.label, this.rate, this.color);
}
