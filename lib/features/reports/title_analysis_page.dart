import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format_utils.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';

class TitleAnalysisPage extends ConsumerStatefulWidget {
  const TitleAnalysisPage({super.key});

  @override
  ConsumerState<TitleAnalysisPage> createState() => _TitleAnalysisPageState();
}

class _TitleAnalysisPageState extends ConsumerState<TitleAnalysisPage> {
  final _db = AppDatabase();
  bool _loading = true;
  String? _error;
  List<_TitleData> _titles = [];
  List<_KeywordStat> _keywordStats = [];
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await _db.getAllVideosWithMetrics();
      final titles = <_TitleData>[];

      for (final v in videos) {
        final plays = (v['play_count'] as int?) ?? 0;
        final title = (v['title'] as String?) ?? '';
        if (title.isEmpty) continue;
        titles.add(_TitleData(
          title: title,
          length: title.length,
          plays: plays,
        ));
      }

      // 关键词分析
      final wordMap = <String, List<int>>{};
      for (final t in titles) {
        final words = _extractKeywords(t.title);
        for (final w in words) {
          wordMap.putIfAbsent(w, () => []);
          wordMap[w]!.add(t.plays);
        }
      }

      final keywordStats = wordMap.entries
          .where((e) => e.value.length >= 2)
          .map((e) => _KeywordStat(
                word: e.key,
                count: e.value.length,
                avgPlays: e.value.fold<int>(0, (s, v) => s + v) ~/ e.value.length,
              ))
          .toList();
      keywordStats.sort((a, b) => b.avgPlays.compareTo(a.avgPlays));
      final topKeywords = keywordStats.take(15).toList();

      // 标题推荐
      final suggestions = _generateSuggestions(topKeywords.take(8).toList());

      if (!mounted) return;
      setState(() {
        _titles = titles;
        _keywordStats = topKeywords;
        _suggestions = suggestions;
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

  List<String> _extractKeywords(String title) {
    final words = <String>{};
    final segments = title
        .replaceAll(RegExp(r'[，。！？、；：\(\)（）【】《》\s#@¥…—\-+=\[\]{}|\\/&*]'), '|')
        .split('|')
        .where((s) => s.length >= 2)
        .toList();

    for (final seg in segments) {
      words.add(seg);
      // Also extract 2-char and 3-char sliding windows for compound terms
      if (seg.length >= 3) {
        for (int i = 0; i <= seg.length - 3; i++) {
          words.add(seg.substring(i, i + 3));
        }
      }
      if (seg.length >= 2) {
        for (int i = 0; i <= seg.length - 2; i++) {
          words.add(seg.substring(i, i + 2));
        }
      }
    }
    // Filter out obvious noise (pure numbers/punctuation/single chars)
    return words
        .where((w) => w.length >= 2 && !RegExp(r'^[0-9\s\.]+$').hasMatch(w))
        .toList();
  }

  List<String> _generateSuggestions(List<_KeywordStat> topKeywords) {
    if (topKeywords.length < 3) {
      return ['数据量不足，导入更多视频后可生成标题推荐'];
    }
    final words = topKeywords.take(6).map((k) => k.word).toList();
    return [
      '【${words[0]}】真的值得买吗？深度评测告诉你答案',
      '挑战${words.length > 1 ? words[1] : words[0]}的极限！结果出乎意料',
      '揭秘${words.length > 2 ? words[2] : words[0]}背后的真相，99%的人不知道',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('封面/标题分析')),
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
    if (_titles.isEmpty) {
      return Center(
          child: Text('暂无数据，请先导入视频',
              style: TextStyle(color: Colors.grey[500])));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildScatterCard(),
        const SizedBox(height: 16),
        _buildKeywordCard(),
        const SizedBox(height: 16),
        _buildSuggestionCard(),
        const SizedBox(height: 16),
        _buildTitleListCard(),
        const SizedBox(height: 80),
      ],
    );
  }

  // ---- 散点图：标题长度 vs 播放量 ----
  Widget _buildScatterCard() {
    final maxLen = _titles.fold<int>(0, (s, t) => t.length > s ? t.length : s);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('标题长度 vs 播放量',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '每个点代表一条视频，X 轴为标题字符数，Y 轴为播放量',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ScatterChart(
                ScatterChartData(
                  scatterSpots: _titles
                      .map((t) => ScatterSpot(
                            t.length.toDouble(),
                            t.plays.toDouble(),
                            dotPainter: FlDotCirclePainter(
                              radius: 5,
                              color: AppTheme.accentBlue.withOpacity(0.6),
                              strokeWidth: 0,
                            ),
                          ))
                      .toList(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.08),
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}字',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey[500]));
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
                  minX: 0,
                  maxX: (maxLen + 5).toDouble(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _correlationText(),
          ],
        ),
      ),
    );
  }

  Widget _correlationText() {
    if (_titles.length < 3) return const SizedBox.shrink();
    // Simple correlation analysis
    double sumXY = 0, sumX = 0, sumY = 0, sumX2 = 0, sumY2 = 0;
    for (final t in _titles) {
      sumXY += t.length * t.plays;
      sumX += t.length;
      sumY += t.plays;
      sumX2 += t.length * t.length;
      sumY2 += t.plays * t.plays;
    }
    final n = _titles.length;
    final denominator = (n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY);
    if (denominator <= 0) return const SizedBox.shrink();
    final r = (n * sumXY - sumX * sumY) / _sqrt(denominator);

    String interpretation;
    Color rColor;
    if (r > 0.3) {
      interpretation = '标题越长，播放量越高（正相关）';
      rColor = AppTheme.accentGreen;
    } else if (r < -0.3) {
      interpretation = '标题越短，播放量越高（负相关）';
      rColor = AppTheme.douyinRed;
    } else {
      interpretation = '相关性不显著，标题长度不是决定因素';
      rColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: rColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, size: 16, color: rColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '相关系数 r=${r.toStringAsFixed(2)} — $interpretation',
              style: TextStyle(fontSize: 12, color: rColor, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  // ---- 关键词分析 ----
  Widget _buildKeywordCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('关键词分析',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('高频词及其对应视频的平均播放量（至少出现 2 次）',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 12),
            if (_keywordStats.isEmpty)
              Text('暂无数据', style: TextStyle(color: Colors.grey[400], fontSize: 12))
            else
              ...List.generate(_keywordStats.length.clamp(0, 10), (i) {
                final k = _keywordStats[i];
                final maxAvg = _keywordStats.isNotEmpty ? _keywordStats.first.avgPlays : 1;
                final ratio = maxAvg > 0 ? (k.avgPlays / maxAvg).clamp(0.05, 1.0) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        '${i + 1}.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                            fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(k.word,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 8,
                                backgroundColor: AppTheme.accentBlue.withOpacity(0.08),
                                valueColor: const AlwaysStoppedAnimation(AppTheme.accentBlue),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('${k.count}条视频 · avg ${formatCount(k.avgPlays)} 播放',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ---- 标题推荐 ----
  Widget _buildSuggestionCard() {
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
                    color: AppTheme.accentAmber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('标题推荐',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text('基于高频高播放词自动生成的标题模板',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 12),
            ..._suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: AppTheme.accentAmber, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(s,
                            style: const TextStyle(fontSize: 13, height: 1.5)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ---- 标题列表 ----
  Widget _buildTitleListCard() {
    final sorted = List<_TitleData>.from(_titles)
      ..sort((a, b) => b.plays.compareTo(a.plays));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('全部标题一览',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  const Expanded(
                      flex: 4,
                      child: Text('标题',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey))),
                  const SizedBox(width: 8),
                  SizedBox(
                      width: 40,
                      child: Text('字数',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
                  const SizedBox(width: 8),
                  SizedBox(
                      width: 50,
                      child: Text('播放量',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
                ],
              ),
            ),
            const Divider(height: 8),
            ...sorted.take(20).map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text('${t.length}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500])),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 50,
                        child: Text(formatCount(t.plays),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600])),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _TitleData {
  final String title;
  final int length;
  final int plays;
  _TitleData({required this.title, required this.length, required this.plays});
}

class _KeywordStat {
  final String word;
  final int count;
  final int avgPlays;
  _KeywordStat({required this.word, required this.count, required this.avgPlays});
}
