import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../services/ai_service.dart';

class TrafficSourcePage extends ConsumerStatefulWidget {
  const TrafficSourcePage({super.key});

  @override
  ConsumerState<TrafficSourcePage> createState() => _TrafficSourcePageState();
}

class _TrafficSourcePageState extends ConsumerState<TrafficSourcePage> {
  final _db = AppDatabase();
  bool _loading = true;
  bool _hasData = false;

  double _recommend = 0;
  double _search = 0;
  double _follow = 0;
  double _city = 0;

  List<Map<String, dynamic>> _topRecommendVideos = [];
  List<Map<String, dynamic>> _topSearchVideos = [];
  List<Map<String, dynamic>> _topFollowVideos = [];

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
      final traffic = await _db.getTrafficSourceAvg();
      final videos = await _db.getAllVideosWithMetrics();

      final withTraffic = videos.where((v) {
        final r = (v['traffic_recommend'] as double?) ?? 0;
        final s = (v['traffic_search'] as double?) ?? 0;
        final f = (v['traffic_follow'] as double?) ?? 0;
        return r > 0 || s > 0 || f > 0;
      }).toList();

      final byRecommend = List<Map<String, dynamic>>.from(withTraffic)
        ..sort((a, b) =>
            ((b['traffic_recommend'] as double?) ?? 0).compareTo((a['traffic_recommend'] as double?) ?? 0));
      final bySearch = List<Map<String, dynamic>>.from(withTraffic)
        ..sort((a, b) =>
            ((b['traffic_search'] as double?) ?? 0).compareTo((a['traffic_search'] as double?) ?? 0));
      final byFollow = List<Map<String, dynamic>>.from(withTraffic)
        ..sort((a, b) =>
            ((b['traffic_follow'] as double?) ?? 0).compareTo((a['traffic_follow'] as double?) ?? 0));

      if (!mounted) return;
      setState(() {
        _recommend = traffic['recommend'] ?? 0;
        _search = traffic['search'] ?? 0;
        _follow = traffic['follow'] ?? 0;
        _city = traffic['city'] ?? 0;
        _hasData = _recommend > 0 || _search > 0 || _follow > 0 || _city > 0;
        _topRecommendVideos = byRecommend.take(5).toList();
        _topSearchVideos = bySearch.take(5).toList();
        _topFollowVideos = byFollow.take(5).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _runAiAnalysis() async {
    setState(() => _aiLoading = true);
    try {
      final result = await AiService.instance.trafficSourceAnalysis({
        'traffic_recommend': _recommend,
        'traffic_search': _search,
        'traffic_follow': _follow,
        'traffic_city': _city,
      });
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
      appBar: AppBar(title: const Text('流量来源分析')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasData
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.traffic, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('暂无流量来源数据',
                            style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                        const SizedBox(height: 6),
                        Text(
                          '导入包含流量来源的详细数据后可分析推荐、搜索、关注、同城流量占比',
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
                    _buildPieChartCard(),
                    const SizedBox(height: 12),
                    _buildSourceDetail('推荐流量', _topRecommendVideos, 'traffic_recommend', AppTheme.douyinRed),
                    const SizedBox(height: 12),
                    _buildSourceDetail('搜索流量', _topSearchVideos, 'traffic_search', AppTheme.accentBlue),
                    const SizedBox(height: 12),
                    _buildSourceDetail('关注流量', _topFollowVideos, 'traffic_follow', AppTheme.accentGreen),
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
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.accentPurple, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Expanded(child: Text('AI 流量结构分析', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                if (_aiLoading)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const Icon(Icons.auto_awesome, size: 14, color: AppTheme.accentPurple),
              ],
            ),
            if (_aiAnalysis != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withValues(alpha: 0.06),
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
              Text('AI 智能分析流量结构健康度，给出各渠道优化建议', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _aiLoading ? null : _runAiAnalysis,
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('开始分析', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: AppTheme.accentPurple,
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
    final total = _recommend + _search + _follow + _city;
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
                const Text('流量结构概览', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _sourceMetric('推荐', _recommend, total, AppTheme.douyinRed)),
                Expanded(child: _sourceMetric('搜索', _search, total, AppTheme.accentBlue)),
                Expanded(child: _sourceMetric('关注', _follow, total, AppTheme.accentGreen)),
                Expanded(child: _sourceMetric('同城', _city, total, AppTheme.accentAmber)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceMetric(String label, double value, double total, Color color) {
    final pct = total > 0 ? value / total * 100 : 0;
    return Column(
      children: [
        Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        SizedBox(
          width: 30,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChartCard() {
    final total = _recommend + _search + _follow + _city;
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
                const Text('流量占比分布', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: [
                          PieChartSectionData(
                            value: _recommend,
                            color: AppTheme.douyinRed,
                            radius: 40,
                            title: '${(_recommend / total * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          PieChartSectionData(
                            value: _search,
                            color: AppTheme.accentBlue,
                            radius: 40,
                            title: '${(_search / total * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          PieChartSectionData(
                            value: _follow,
                            color: AppTheme.accentGreen,
                            radius: 40,
                            title: '${(_follow / total * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          if (_city > 0)
                            PieChartSectionData(
                              value: _city,
                              color: AppTheme.accentAmber,
                              radius: 40,
                              title: '${(_city / total * 100).toStringAsFixed(0)}%',
                              titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _legendItem('推荐流量', AppTheme.douyinRed),
                        const SizedBox(height: 6),
                        _legendItem('搜索流量', AppTheme.accentBlue),
                        const SizedBox(height: 6),
                        _legendItem('关注流量', AppTheme.accentGreen),
                        const SizedBox(height: 6),
                        if (_city > 0) _legendItem('同城流量', AppTheme.accentAmber),
                      ],
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

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildSourceDetail(String title, List<Map<String, dynamic>> videos, String key, Color color) {
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
            if (videos.isEmpty)
              Text('暂无数据', style: TextStyle(fontSize: 11, color: Colors.grey[500]))
            else
              ...videos.asMap().entries.map((entry) {
                final idx = entry.key;
                final v = entry.value;
                final val = (v[key] as double?) ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: idx < 3 ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        alignment: Alignment.center,
                        child: Text('${idx + 1}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: idx < 3 ? color : Colors.grey[600])),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(v['title'] as String? ?? '无标题', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      Text('${val.toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
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
