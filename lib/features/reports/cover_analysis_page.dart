import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format_utils.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../services/ai_service.dart';

class CoverAnalysisPage extends ConsumerStatefulWidget {
  const CoverAnalysisPage({super.key});

  @override
  ConsumerState<CoverAnalysisPage> createState() => _CoverAnalysisPageState();
}

class _CoverAnalysisPageState extends ConsumerState<CoverAnalysisPage> {
  final _db = AppDatabase();
  bool _loading = true;
  bool _hasData = false;
  String? _error;

  double _avgCtr = 0;
  double _maxCtr = 0;
  double _minCtr = 0;
  int _totalWithCtr = 0;

  List<Map<String, dynamic>> _highCtrVideos = [];
  List<Map<String, dynamic>> _lowCtrVideos = [];
  final List<_CtrBucket> _ctrBuckets = [];

  String? _aiAnalysis;
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
      // 重置累加字段
      _ctrBuckets.clear();

      final withCtr = videos.where((v) {
        final ctr = (v['cover_ctr'] as double?) ?? 0;
        return ctr > 0;
      }).toList();

      if (withCtr.isEmpty) {
        setState(() {
          _loading = false;
          _hasData = false;
        });
        return;
      }

      double totalCtr = 0;
      double maxCtr = 0;
      double minCtr = 999;

      // Initialize buckets
      final bucketMap = <String, int>{
        '0-5%': 0,
        '5-10%': 0,
        '10-15%': 0,
        '15-20%': 0,
        '20-25%': 0,
        '25-30%': 0,
        '30%+': 0,
      };

      for (final v in withCtr) {
        final ctr = (v['cover_ctr'] as double?) ?? 0;
        totalCtr += ctr;
        if (ctr > maxCtr) maxCtr = ctr;
        if (ctr < minCtr) minCtr = ctr;

        if (ctr < 5) {
          bucketMap['0-5%'] = bucketMap['0-5%']! + 1;
        } else if (ctr < 10) {
          bucketMap['5-10%'] = bucketMap['5-10%']! + 1;
        } else if (ctr < 15) {
          bucketMap['10-15%'] = bucketMap['10-15%']! + 1;
        } else if (ctr < 20) {
          bucketMap['15-20%'] = bucketMap['15-20%']! + 1;
        } else if (ctr < 25) {
          bucketMap['20-25%'] = bucketMap['20-25%']! + 1;
        } else if (ctr < 30) {
          bucketMap['25-30%'] = bucketMap['25-30%']! + 1;
        } else {
          bucketMap['30%+'] = bucketMap['30%+']! + 1;
        }
      }

      final sorted = List<Map<String, dynamic>>.from(withCtr)
        ..sort((a, b) =>
            ((b['cover_ctr'] as double?) ?? 0).compareTo((a['cover_ctr'] as double?) ?? 0));

      final ctrBuckets = bucketMap.entries
          .map((e) => _CtrBucket(e.key, e.value))
          .toList();

      if (!mounted) return;
      setState(() {
        _avgCtr = totalCtr / withCtr.length;
        _maxCtr = maxCtr;
        _minCtr = minCtr;
        _totalWithCtr = withCtr.length;
        _highCtrVideos = sorted.take(5).toList();
        _lowCtrVideos = sorted.reversed.take(5).toList();
        _ctrBuckets.addAll(ctrBuckets);
        _hasData = true;
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

  Future<void> _runAiAnalysis() async {
    setState(() => _aiLoading = true);
    try {
      final videos = await _db.getAllVideosWithMetrics();
      final withCtr = videos.where((v) {
        final ctr = (v['cover_ctr'] as double?) ?? 0;
        return ctr > 0;
      }).toList();
      final result = await AiService.instance.coverAnalysis(withCtr);
      if (!mounted) return;
      setState(() {
        _aiAnalysis = result;
        _aiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiAnalysis = '分析失败: $e';
        _aiLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('封面分析')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('加载失败: $_error', style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _loadData, child: const Text('重试')),
                    ],
                  ),
                )
              : !_hasData
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('暂无封面点击率数据',
                            style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                        const SizedBox(height: 6),
                        Text(
                          '导入包含封面点击率的详细数据后可分析封面效果',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildAiCard(),
                    const SizedBox(height: 12),
                    _buildOverviewCard(),
                    const SizedBox(height: 12),
                    _buildDistributionCard(),
                    const SizedBox(height: 12),
                    _buildHighLowCard('高CTR封面 TOP5', _highCtrVideos, AppTheme.accentGreen),
                    const SizedBox(height: 12),
                    _buildHighLowCard('低CTR封面 Bottom5', _lowCtrVideos, AppTheme.douyinRed),
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
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.accentAmber, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Expanded(child: Text('AI 封面优化建议', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                if (_aiLoading)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const Icon(Icons.auto_awesome, size: 14, color: AppTheme.accentAmber),
              ],
            ),
            if (_aiAnalysis != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_aiAnalysis!, style: const TextStyle(fontSize: 12, height: 1.6)),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _aiLoading ? null : _runAiAnalysis,
                  child: const Text('重新分析', style: TextStyle(fontSize: 11)),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text('AI 智能分析封面效果，给出高点击率封面设计建议', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _aiLoading ? null : _runAiAnalysis,
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('获取建议', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: AppTheme.accentAmber,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
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
                const Text('封面效果概览', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _metricItem('平均CTR', '${_avgCtr.toStringAsFixed(1)}%', AppTheme.accentBlue)),
                Expanded(child: _metricItem('最高CTR', '${_maxCtr.toStringAsFixed(1)}%', AppTheme.accentGreen)),
                Expanded(child: _metricItem('最低CTR', '${_minCtr.toStringAsFixed(1)}%', AppTheme.douyinRed)),
                Expanded(child: _metricItem('样本数', '$_totalWithCtr', Colors.grey[600]!)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getCtrLevelColor().withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: _getCtrLevelColor()),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _getCtrLevelText(),
                      style: TextStyle(fontSize: 11, color: _getCtrLevelColor(), fontWeight: FontWeight.w500),
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

  Color _getCtrLevelColor() {
    if (_avgCtr >= 15) return AppTheme.accentGreen;
    if (_avgCtr >= 8) return AppTheme.accentAmber;
    return AppTheme.douyinRed;
  }

  String _getCtrLevelText() {
    if (_avgCtr >= 15) return '封面点击率优秀，超过大多数同类账号';
    if (_avgCtr >= 8) return '封面点击率中等，仍有提升空间';
    return '封面点击率偏低，建议重点优化封面设计';
  }

  Widget _metricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildDistributionCard() {
    final maxCount = _ctrBuckets.fold<int>(0, (s, b) => s > b.count ? s : b.count);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.douyinCyan, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Text('CTR 分布', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount * 1.2,
                  barGroups: _ctrBuckets.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final bucket = entry.value;
                    final colors = [
                      Colors.red[400]!,
                      Colors.orange[400]!,
                      Colors.amber[400]!,
                      Colors.yellow[400]!,
                      Colors.lightGreen[400]!,
                      Colors.green[400]!,
                      Colors.teal[400]!,
                    ];
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: bucket.count.toDouble(),
                          color: colors[idx % colors.length],
                          width: 18,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(2), topRight: Radius.circular(2)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _ctrBuckets.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_ctrBuckets[idx].label, style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                          );
                        },
                        reservedSize: 20,
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

  Widget _buildHighLowCard(String title, List<Map<String, dynamic>> videos, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 8),
            ...videos.asMap().entries.map((entry) {
              final idx = entry.key;
              final v = entry.value;
              final ctr = (v['cover_ctr'] as double?) ?? 0;
              final plays = (v['play_count'] as int?) ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: idx < 3 ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text('${idx + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: idx < 3 ? color : Colors.grey[600])),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v['title'] as String? ?? '无标题', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                          const SizedBox(height: 1),
                          Text('${formatCount(plays)} 播放', style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${ctr.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CtrBucket {
  final String label;
  final int count;
  _CtrBucket(this.label, this.count);
}
