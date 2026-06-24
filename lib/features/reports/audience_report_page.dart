import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format_utils.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../services/ai_service.dart';

class AudienceReportPage extends ConsumerStatefulWidget {
  const AudienceReportPage({super.key});

  @override
  ConsumerState<AudienceReportPage> createState() =>
      _AudienceReportPageState();
}

class _AudienceReportPageState extends ConsumerState<AudienceReportPage>
    with SingleTickerProviderStateMixin {
  final _db = AppDatabase();
  bool _loading = true;
  late TabController _tabController;

  int _totalVideos = 0;
  int _totalPlays = 0;
  double _avgFinishRate = 0.0;
  double _avgWatchDuration = 0.0;
  double _likeRate = 0.0;
  double _commentRate = 0.0;
  double _shareRate = 0.0;

  double _maleRatio = 0.5;
  double _femaleRatio = 0.5;
  Map<String, double> _ageDistribution = {};
  List<MapEntry<String, double>> _regionDistribution = [];
  bool _hasAudienceData = false;
  bool _aiInterpreting = false;
  String? _aiInterpretation;

  final Map<String, int> _finishRateBuckets = {
    '0-20%': 0,
    '20-40%': 0,
    '40-60%': 0,
    '60-80%': 0,
    '80-100%': 0,
  };

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
    setState(() => _loading = true);
    try {
      final videos = await _db.getAllVideosWithMetrics();
      int plays = 0, likes = 0, comments = 0, shares = 0;
      double totalFinishRate = 0, totalWatch = 0;
      int finishRateCount = 0, watchCount = 0;

      double totalMaleRatio = 0;
      int maleRatioCount = 0;
      final Map<String, double> ageAgg = {};
      final Map<String, double> regionAgg = {};
      int audienceDataCount = 0;

      for (final v in videos) {
        plays += (v['play_count'] as int?) ?? 0;
        likes += (v['like_count'] as int?) ?? 0;
        comments += (v['comment_count'] as int?) ?? 0;
        shares += (v['share_count'] as int?) ?? 0;

        final fr = (v['finish_rate'] as double?) ?? 0.0;
        final aw = (v['avg_watch_duration'] as double?) ?? 0.0;

        if (fr > 0) {
          totalFinishRate += fr;
          finishRateCount++;
        }
        if (aw > 0) {
          totalWatch += aw;
          watchCount++;
        }

        if (fr <= 20) {
          _finishRateBuckets['0-20%'] = (_finishRateBuckets['0-20%'] ?? 0) + 1;
        } else if (fr <= 40) {
          _finishRateBuckets['20-40%'] = (_finishRateBuckets['20-40%'] ?? 0) + 1;
        } else if (fr <= 60) {
          _finishRateBuckets['40-60%'] = (_finishRateBuckets['40-60%'] ?? 0) + 1;
        } else if (fr <= 80) {
          _finishRateBuckets['60-80%'] = (_finishRateBuckets['60-80%'] ?? 0) + 1;
        } else {
          _finishRateBuckets['80-100%'] = (_finishRateBuckets['80-100%'] ?? 0) + 1;
        }

        final maleRatio = (v['audience_male_ratio'] as double?) ?? 0.0;
        if (maleRatio > 0) {
          totalMaleRatio += maleRatio;
          maleRatioCount++;
          audienceDataCount++;
        }

        final ageDistStr = (v['audience_age_dist'] as String?) ?? '';
        if (ageDistStr.isNotEmpty) {
          try {
            final ageMap = Map<String, double>.from(jsonDecode(ageDistStr));
            ageMap.forEach((key, value) {
              ageAgg[key] = (ageAgg[key] ?? 0) + value;
            });
            audienceDataCount++;
          } catch (_) {}
        }

        final regionDistStr = (v['audience_region_dist'] as String?) ?? '';
        if (regionDistStr.isNotEmpty) {
          try {
            final regionMap = Map<String, double>.from(jsonDecode(regionDistStr));
            regionMap.forEach((key, value) {
              regionAgg[key] = (regionAgg[key] ?? 0) + value;
            });
            audienceDataCount++;
          } catch (_) {}
        }
      }

      if (maleRatioCount > 0) {
        _maleRatio = totalMaleRatio / maleRatioCount;
        _femaleRatio = 1 - _maleRatio;
      }

      if (ageAgg.isNotEmpty) {
        final total = ageAgg.values.fold<double>(0, (s, v) => s + v);
        _ageDistribution = ageAgg.map((k, v) => MapEntry(k, v / total));
      }

      if (regionAgg.isNotEmpty) {
        final total = regionAgg.values.fold<double>(0, (s, v) => s + v);
        _regionDistribution = regionAgg.entries
            .map((e) => MapEntry(e.key, e.value / total))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (_regionDistribution.length > 10) {
          _regionDistribution = _regionDistribution.sublist(0, 10);
        }
      }

      if (!mounted) return;
      setState(() {
        _totalVideos = videos.length;
        _totalPlays = plays;
        _avgFinishRate = finishRateCount > 0 ? totalFinishRate / finishRateCount : 0.0;
        _avgWatchDuration = watchCount > 0 ? totalWatch / watchCount : 0.0;
        _likeRate = plays > 0 ? likes / plays * 100 : 0;
        _commentRate = plays > 0 ? comments / plays * 100 : 0;
        _shareRate = plays > 0 ? shares / plays * 100 : 0;
        _hasAudienceData = audienceDataCount > 0;
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
      appBar: AppBar(
        title: const Text('受众分析'),
        bottom: _loading
            ? null
            : TabBar(
                controller: _tabController,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: '核心指标'),
                  Tab(text: '粉丝画像'),
                  Tab(text: '互动分析'),
                ],
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_totalVideos == 0) {
      return Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildAudienceTab(),
        _buildEngagementTab(),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _buildOverviewCard(),
        const SizedBox(height: 10),
        _buildFinishRateCard(),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildAudienceTab() {
    if (!_hasAudienceData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('暂无粉丝画像数据',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600])),
              const SizedBox(height: 6),
              Text(
                '导入包含粉丝画像的 CSV 数据后可查看性别、年龄、地域分布',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _buildAiInterpretationCard(),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildGenderCard()),
            const SizedBox(width: 10),
            Expanded(child: _buildAgeCard()),
          ],
        ),
        const SizedBox(height: 10),
        _buildRegionCard(),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildEngagementTab() {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _buildEngagementCard(),
        const SizedBox(height: 60),
      ],
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
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.douyinRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('核心指标',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _metricBox('总播放', formatCount(_totalPlays),
                      AppTheme.douyinRed),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricBox('均完播率',
                      '${_avgFinishRate.toStringAsFixed(1)}%',
                      const Color(0xFF4CAF50)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricBox('均观看时长',
                      '${_avgWatchDuration.toStringAsFixed(1)}s',
                      AppTheme.douyinCyan),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricBox('视频数', '$_totalVideos',
                      AppTheme.accentPurple),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildFinishRateCard() {
    final buckets = _finishRateBuckets.entries.toList();
    final total = buckets.fold<int>(0, (s, e) => s + e.value);
    final colors = [
      Colors.red[400]!,
      Colors.orange[400]!,
      Colors.yellow[400]!,
      Colors.lightGreen[400]!,
      Colors.green[400]!,
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
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('完播率分布',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            if (total == 0)
              Text('暂无完播率数据',
                  style: TextStyle(color: Colors.grey[500]))
            else
              ...buckets.asMap().entries.map((entry) {
                final idx = entry.key;
                final bucket = entry.value;
                final ratio = bucket.value / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(bucket.key,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 12,
                            backgroundColor:
                                colors[idx].withValues(alpha: 0.15),
                            valueColor:
                                AlwaysStoppedAnimation(colors[idx]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 28,
                        child: Text(
                          bucket.value.toString(),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12),
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

  Widget _buildGenderCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('性别分布',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SizedBox(
              height: 130,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 28,
                  sections: [
                    PieChartSectionData(
                      value: _maleRatio * 100,
                      color: AppTheme.accentBlue,
                      title: '${(_maleRatio * 100).toStringAsFixed(0)}%',
                      radius: 36,
                      titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: _femaleRatio * 100,
                      color: AppTheme.douyinRed,
                      title: '${(_femaleRatio * 100).toStringAsFixed(0)}%',
                      radius: 36,
                      titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(AppTheme.accentBlue),
                const SizedBox(width: 4),
                const Text('男', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 16),
                _legendDot(AppTheme.douyinRed),
                const SizedBox(width: 4),
                const Text('女', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeCard() {
    final entries = _ageDistribution.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('年龄分布',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Text('暂无年龄数据', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final colors = [
      AppTheme.accentBlue,
      AppTheme.accentPurple,
      AppTheme.douyinRed,
      AppTheme.accentAmber,
      AppTheme.accentGreen,
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('年龄分布',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SizedBox(
              height: 130,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              entries[idx].key.replaceAll('岁', ''),
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey[600]),
                            ),
                          );
                        },
                        reservedSize: 20,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final e = entry.value;
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: e.value,
                          color: colors[idx % colors.length],
                          width: 16,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionCard() {
    if (_regionDistribution.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('地域分布 TOP10',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text('暂无地域数据', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('地域分布 TOP10',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            ..._regionDistribution.asMap().entries.map((entry) {
              final idx = entry.key;
              final region = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentAmber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: Text(
                        region.key,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: region.value,
                          minHeight: 6,
                          backgroundColor:
                              AppTheme.accentAmber.withValues(alpha: 0.1),
                          valueColor:
                              const AlwaysStoppedAnimation(AppTheme.accentAmber),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${(region.value * 100).toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[600]),
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

  Widget _buildAiInterpretationCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _aiInterpreting
          ? null
          : () async {
              setState(() {
                _aiInterpreting = true;
              });
              try {
                final ai = AiService.instance;
                final result = await ai.audienceInterpretation(
                  maleRatio: _maleRatio,
                  ageDistribution: _ageDistribution,
                  topRegions: _regionDistribution.take(5).toList(),
                );
                if (!mounted) return;
                setState(() {
                  _aiInterpretation = result;
                });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _aiInterpretation = '解读失败: $e';
                });
              } finally {
                if (mounted) {
                  setState(() {
                    _aiInterpreting = false;
                  });
                }
              }
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2A1F3D), const Color(0xFF1A1A2E)]
                : [const Color(0xFFF3E8FF), const Color(0xFFEEF2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: _aiInterpreting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('AI 解读中...',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              )
            : _aiInterpretation != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: AppTheme.accentPurple, size: 16),
                          const SizedBox(width: 6),
                          const Text('AI 粉丝画像解读',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('重新解读',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.accentPurple,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_aiInterpretation!,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: Colors.grey[800])),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.psychology_alt,
                            color: AppTheme.accentPurple, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AI 智能解读粉丝画像',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('基于性别、年龄、地域生成专业分析',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          size: 12, color: Colors.grey[400]),
                    ],
                  ),
      ),
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildEngagementCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.douyinCyan,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('互动率分析',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            _engagementRow('点赞率', _likeRate, AppTheme.douyinRed),
            _engagementRow('评论率', _commentRate, const Color(0xFF7C4DFF)),
            _engagementRow('分享率', _shareRate, AppTheme.douyinCyan),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getEngagementTip(),
                      style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.5),
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

  String _getEngagementTip() {
    if (_likeRate < 2) {
      return '点赞率偏低，建议优化视频开头3秒钩子，提升内容价值感，引导观众点赞收藏。';
    } else if (_commentRate < 0.2) {
      return '评论率偏低，建议在视频中设置互动话题、提问或争议性观点，激发评论欲望。';
    } else if (_shareRate < 0.1) {
      return '分享率偏低，建议增加实用干货、情感共鸣或社交货币属性的内容，提升转发意愿。';
    }
    return '互动数据表现良好，继续保持内容质量，可尝试更多互动玩法提升粉丝粘性。';
  }

  Widget _engagementRow(String label, double rate, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
              width: 55,
              child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (rate / 10).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            child: Text('${rate.toStringAsFixed(2)}%',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
