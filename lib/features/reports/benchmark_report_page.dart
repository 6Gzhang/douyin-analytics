import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/format_utils.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';

class BenchmarkReportPage extends ConsumerStatefulWidget {
  const BenchmarkReportPage({super.key});

  @override
  ConsumerState<BenchmarkReportPage> createState() =>
      _BenchmarkReportPageState();
}

class _BenchmarkReportPageState extends ConsumerState<BenchmarkReportPage> {
  final _db = AppDatabase();
  bool _loading = true;
  String? _error;
  List<int> _allPlays = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final videos = await _db.getAllVideos();
      final plays = <int>[];
      for (final v in videos) {
        final metrics = await _db.getMetricsForVideo(v['id'] as String);
        if (metrics != null) {
          plays.add((metrics['play_count'] as int?) ?? 0);
        }
      }
      plays.sort();
      if (!mounted) return;
      setState(() {
        _allPlays = plays;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('竞品对比报告')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败: $_error', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_allPlays.isEmpty) {
      return Center(
        child: Text('暂无播放数据', style: TextStyle(color: Colors.grey[500])),
      );
    }

    final n = _allPlays.length;
    final median = n > 0 ? _allPlays[n ~/ 2] : 0;
    final p75 = n > 0 ? _allPlays[(n * 0.75).round().clamp(0, n - 1)] : 0;
    final p90 = n > 0 ? _allPlays[(n * 0.90).round().clamp(0, n - 1)] : 0;

    // 播放量分桶
    final buckets = <String, int>{
      '0-1k': 0,
      '1k-5k': 0,
      '5k-10k': 0,
      '10k-50k': 0,
      '50k+': 0,
    };
    for (final p in _allPlays) {
      if (p < 1000) {
        buckets['0-1k'] = (buckets['0-1k'] ?? 0) + 1;
      } else if (p < 5000) {
        buckets['1k-5k'] = (buckets['1k-5k'] ?? 0) + 1;
      } else if (p < 10000) {
        buckets['5k-10k'] = (buckets['5k-10k'] ?? 0) + 1;
      } else if (p < 50000) {
        buckets['10k-50k'] = (buckets['10k-50k'] ?? 0) + 1;
      } else {
        buckets['50k+'] = (buckets['50k+'] ?? 0) + 1;
      }
    }

    final barData = buckets.entries.toList();
    final maxCount = barData.fold<int>(0, (s, e) => s > e.value ? s : e.value);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPercentileCard(median, p75, p90),
        const SizedBox(height: 16),
        _buildDistributionChart(barData, maxCount),
        const SizedBox(height: 16),
        _buildIndustryCompareCard(median),
      ],
    );
  }

  Widget _buildPercentileCard(int median, int p75, int p90) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('播放量百分位分布',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _percentileBox('中位数 (P50)', formatCount(median),
                      AppTheme.douyinRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _percentileBox('前 25% (P75)', formatCount(p75),
                      const Color(0xFF7C4DFF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _percentileBox('前 10% (P90)', formatCount(p90),
                      AppTheme.douyinCyan),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '共 ${_allPlays.length} 条视频，播放量范围 ${formatCount(_allPlays.first)} - ${formatCount(_allPlays.last)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _percentileBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDistributionChart(
      List<MapEntry<String, int>> barData, int maxCount) {
    final barColors = [
      Colors.red[300]!,
      Colors.orange[300]!,
      Colors.yellow[700]!,
      Colors.lightGreen[400]!,
      Colors.green[400]!,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('播放量分桶分布',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxCount / 4).ceilToDouble().clamp(1, double.infinity),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.15),
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < barData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(barData[idx].key,
                                  style: TextStyle(
                                      fontSize: 9, color: Colors.grey[500])),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barData.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final data = entry.value;
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: data.value.toDouble(),
                          color: barColors[idx % barColors.length],
                          width: 24,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  minY: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndustryCompareCard(int median) {
    final industryAvgLow = 3000;
    final industryAvgHigh = 5000;
    String comparison;
    Color cmpColor;

    if (median >= industryAvgHigh) {
      comparison = '高于行业平均（3000-5000），表现优异';
      cmpColor = Colors.green;
    } else if (median >= industryAvgLow) {
      comparison = '在行业平均范围内（3000-5000），中规中矩';
      cmpColor = Colors.orange;
    } else {
      comparison = '低于行业平均水平（3000-5000），有提升空间';
      cmpColor = AppTheme.douyinRed;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('与行业平均水平对比',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '抖音视频平均播放量约 ${formatCount(industryAvgLow)}-${formatCount(industryAvgHigh)}（经验值）',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cmpColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cmpColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '你的中位数播放量: ${formatCount(median)}\n$comparison',
                      style: TextStyle(fontSize: 13, color: cmpColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
