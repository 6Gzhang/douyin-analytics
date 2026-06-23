import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format_utils.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../services/ai_service.dart';

class PublishCalendarPage extends ConsumerStatefulWidget {
  const PublishCalendarPage({super.key});

  @override
  ConsumerState<PublishCalendarPage> createState() =>
      _PublishCalendarPageState();
}

class _PublishCalendarPageState extends ConsumerState<PublishCalendarPage>
    with SingleTickerProviderStateMixin {
  final _db = AppDatabase();
  bool _loading = true;
  late TabController _tabController;

  final Map<int, List<int>> _weekdayPlays = {};
  final Map<int, List<int>> _hourPlays = {};
  final List<Map<String, dynamic>> _comboList = [];
  List<Map<String, dynamic>> _top10 = [];
  String _aiSuggestion = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final videos = await _db.getAllVideosWithMetrics();
    for (final v in videos) {
      final plays = (v['play_count'] as int?) ?? 0;
      if (plays <= 0) continue;
      final ct = v['create_time'] as int?;
      if (ct == null || ct == 0) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ct * 1000);
      final wd = dt.weekday; // 1=Mon, 7=Sun
      final hr = dt.hour;

      _weekdayPlays.putIfAbsent(wd, () => []).add(plays);
      _hourPlays.putIfAbsent(hr, () => []).add(plays);
      _comboList.add({'weekday': wd, 'hour': hr, 'plays': plays});
    }

    // Calculate combo top 10
    final combos = <String, List<int>>{};
    for (final c in _comboList) {
      final key = '${c['weekday']}_${c['hour']}';
      combos.putIfAbsent(key, () => []).add(c['plays'] as int);
    }
    final avgList = <Map<String, dynamic>>[];
    for (final entry in combos.entries) {
      final parts = entry.key.split('_');
      final sum = entry.value.fold<int>(0, (a, b) => a + b);
      avgList.add({
        'weekday': int.parse(parts[0]),
        'hour': int.parse(parts[1]),
        'count': entry.value.length,
        'avg_plays': sum / entry.value.length,
      });
    }
    avgList.sort((a, b) => (b['avg_plays'] as double).compareTo(a['avg_plays'] as double));
    _top10 = avgList.take(10).toList();

    if (!mounted) return;
    setState(() => _loading = false);
    _fetchAiSuggestion();
  }

  Future<void> _fetchAiSuggestion() async {
    if (_top10.isEmpty) return;
    final sb = StringBuffer();
    sb.writeln('我的抖音频道最佳发布时段（按平均播放量排序）Top 10：');
    for (int i = 0; i < _top10.length; i++) {
      final t = _top10[i];
      final wdNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final wd = wdNames[t['weekday'] as int];
      final hr = '${t['hour']}:00';
      sb.writeln('${i + 1}. $wd $hr — 平均 ${formatCount((t['avg_plays'] as double).round())} 播放');
    }
    sb.writeln();
    sb.writeln('请基于以上数据，推荐 1 个最佳发布窗口（精确到周几+时间段）并简要说理由（一句话）。');

    final reply = await AiService.instance.chat(
      '你是抖音运营专家，擅长分析发布时机数据。回答简短（≤50字），直接给结论。',
      sb.toString(),
    );
    if (mounted && reply.isNotEmpty && !reply.startsWith('请先')) {
      setState(() => _aiSuggestion = reply);
    }
  }

  String _weekdayName(int wd) {
    const names = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[wd];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('最佳发布时机'),
        bottom: _loading || _comboList.isEmpty
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '星期分析'),
                  Tab(text: '小时分析'),
                  Tab(text: '最佳时段'),
                ],
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _comboList.isEmpty
              ? Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildWeekdayChart(),
                        if (_aiSuggestion.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildAiCard(),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildHourChart(),
                        const SizedBox(height: 40),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildTop10Table(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _buildWeekdayChart() {
    final avgs = <int, double>{};
    for (final entry in _weekdayPlays.entries) {
      final sum = entry.value.fold<int>(0, (a, b) => a + b);
      avgs[entry.key] = sum / entry.value.length;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('按星期几 — 平均播放量',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (avgs.values.isEmpty ? 1 : avgs.values.reduce((a, b) => a > b ? a : b)) * 1.2,
                  barGroups: List.generate(7, (i) {
                    final wd = i + 1;
                    return BarChartGroupData(x: wd, barRods: [
                      BarChartRodData(
                        toY: avgs[wd] ?? 0,
                        color: AppTheme.douyinRed,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
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
                          final wd = val.toInt();
                          if (wd < 1 || wd > 7) return const SizedBox.shrink();
                          return Text(_weekdayName(wd), style: const TextStyle(fontSize: 11));
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

  Widget _buildHourChart() {
    final avgs = <int, double>{};
    for (final entry in _hourPlays.entries) {
      final sum = entry.value.fold<int>(0, (a, b) => a + b);
      avgs[entry.key] = sum / entry.value.length;
    }
    final spots = avgs.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('按小时 — 平均播放量',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.accentBlue,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.accentBlue.withValues(alpha: 0.1),
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
                        reservedSize: 24,
                        interval: 3,
                        getTitlesWidget: (val, _) {
                          return Text('${val.toInt()}:00', style: const TextStyle(fontSize: 10));
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

  Widget _buildTop10Table() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top 10 最佳发布时段',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
                2: IntrinsicColumnWidth(),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('时段', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('', style: TextStyle(fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('均播', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                ..._top10.map((t) => TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '${_weekdayName(t['weekday'] as int)} ${t['hour']}:00',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const Padding(padding: EdgeInsets.all(8), child: SizedBox()),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          formatCount((t['avg_plays'] as double).round()),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiCard() {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              AppTheme.accentPurple.withValues(alpha: 0.05),
              AppTheme.accentBlue.withValues(alpha: 0.03),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.accentPurple, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI 推荐最佳发布窗口',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(_aiSuggestion,
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
