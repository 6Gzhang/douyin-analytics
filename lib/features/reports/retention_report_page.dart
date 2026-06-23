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
  ConsumerState<RetentionReportPage> createState() =>
      _RetentionReportPageState();
}

class _RetentionReportPageState extends ConsumerState<RetentionReportPage> {
  final _db = AppDatabase();
  bool _loading = true;

  final List<double> _finishRates = [];
  double _avgFR = 0;
  double _medianFR = 0;
  String _aiInsight = '';

  // Histogram buckets
  final Map<int, int> _histogram = {};
  // Scatter: (plays, finishRate)
  final List<_ScatterPoint> _scatter = [];
  // Recent 10 video 5-second finish rate
  final List<double> _fiveSecTrend = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final videos = await _db.getAllVideos();
    for (final v in videos) {
      final metrics = await _db.getMetricsForVideo(v['id'] as String);
      if (metrics == null) continue;
      final fr = (metrics['finish_rate'] as double?) ?? 0;
      final plays = (metrics['play_count'] as int?) ?? 0;
      final fsr = (metrics['five_second_finish_rate'] as double?) ?? 0;
      if (fr > 0) {
        _finishRates.add(fr);
        _scatter.add(_ScatterPoint(plays, fr));
        final bucket = (fr / 10).floor().clamp(0, 9);
        _histogram[bucket] = (_histogram[bucket] ?? 0) + 1;
      }
      if (fsr > 0) _fiveSecTrend.add(fsr);
    }

    if (_finishRates.isNotEmpty) {
      final sorted = List<double>.from(_finishRates)..sort();
      final sum = _finishRates.fold<double>(0, (a, b) => a + b);
      _avgFR = sum / _finishRates.length;
      if (sorted.length % 2 == 0) {
        _medianFR = (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;
      } else {
        _medianFR = sorted[sorted.length ~/ 2];
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);
    _fetchAiInsight();
  }

  Future<void> _fetchAiInsight() async {
    if (_finishRates.isEmpty) return;
    final sb = StringBuffer();
    sb.writeln('我的抖音频道完播率分析数据：');
    sb.writeln('平均完播率：${_avgFR.toStringAsFixed(1)}%');
    sb.writeln('中位数完播率：${_medianFR.toStringAsFixed(1)}%');
    sb.writeln('总视频数：${_finishRates.length}');
    sb.writeln();
    sb.writeln('请简要分析完播率整体水平并给1条关键改进建议。回答在50字以内。');

    final reply = await AiService.instance.chat(
      '你是抖音内容优化专家。回答简洁，≤50字。',
      sb.toString(),
    );
    if (mounted && reply.isNotEmpty && !reply.startsWith('请先')) {
      setState(() => _aiInsight = reply);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('完播率深度分析')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _finishRates.isEmpty
              ? Center(child: Text('暂无完播率数据', style: TextStyle(color: Colors.grey[500])))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummary(),
                    const SizedBox(height: 20),
                    _buildHistogram(),
                    const SizedBox(height: 20),
                    _buildScatter(),
                    if (_fiveSecTrend.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildFiveSecTrend(),
                    ],
                    if (_aiInsight.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildAiInsight(),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
    );
  }

  Widget _buildSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem('平均完播率', '${_avgFR.toStringAsFixed(1)}%', AppTheme.douyinRed),
            _summaryItem('中位数完播率', '${_medianFR.toStringAsFixed(1)}%', AppTheme.accentBlue),
            _summaryItem('视频数', '${_finishRates.length}', AppTheme.accentGreen),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildHistogram() {
    final maxCount = _histogram.values.isEmpty ? 1 : _histogram.values.reduce(max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('完播率分布直方图',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount * 1.2,
                  barGroups: List.generate(10, (i) {
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: (_histogram[i] ?? 0).toDouble(),
                        color: AppTheme.accentBlue,
                        width: 14,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(3),
                          topRight: Radius.circular(3),
                        ),
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
                          return Text('${i * 10}%', style: const TextStyle(fontSize: 10));
                        },
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('完播率 vs 播放量 散点图',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ScatterChart(
                ScatterChartData(
                  scatterSpots: _scatter
                      .map((s) => ScatterSpot(s.plays.toDouble(), s.finishRate))
                      .toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          return Text(formatCount(val.toInt()), style: const TextStyle(fontSize: 9));
                        },
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

  Widget _buildFiveSecTrend() {
    final recent10 = _fiveSecTrend.length > 10
        ? _fiveSecTrend.sublist(_fiveSecTrend.length - 10)
        : _fiveSecTrend;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最近 ${_fiveSecTrend.length > 10 ? "10" : ""}条视频 5秒完播率趋势',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: recent10.asMap().entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value))
                          .toList(),
                      isCurved: true,
                      color: AppTheme.accentGreen,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, ____) =>
                            FlDotCirclePainter(
                                radius: 3,
                                color: AppTheme.accentGreen,
                                strokeWidth: 0),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.accentGreen.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          return Text('#${val.toInt() + 1}', style: const TextStyle(fontSize: 10));
                        },
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

  Widget _buildAiInsight() {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              AppTheme.accentGreen.withValues(alpha: 0.05),
              AppTheme.accentBlue.withValues(alpha: 0.03),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.accentGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI 完播率洞察',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(_aiInsight,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5)),
                ],
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
