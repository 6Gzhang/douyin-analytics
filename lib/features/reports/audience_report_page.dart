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
  ConsumerState<AudienceReportPage> createState() => _AudienceReportPageState();
}

class _AudienceReportPageState extends ConsumerState<AudienceReportPage> with SingleTickerProviderStateMixin {
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
  double _collectRate = 0.0;

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

  String _coreAgeGroup = '';
  double _coreAgeRatio = 0;
  String _topRegion = '';
  double _topRegionRatio = 0;

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
      int plays = 0, likes = 0, comments = 0, shares = 0, collects = 0;
      double totalFinishRate = 0, totalWatch = 0;
      int finishRateCount = 0, watchCount = 0;

      double totalMaleRatio = 0;
      int maleRatioCount = 0;
      final Map<String, double> ageAgg = {};
      final Map<String, double> regionAgg = {};
      int audienceDataCount = 0;

      // 重置累加字段
      _finishRateBuckets.updateAll((key, value) => 0);

      for (final v in videos) {
        plays += (v['play_count'] as int?) ?? 0;
        likes += (v['like_count'] as int?) ?? 0;
        comments += (v['comment_count'] as int?) ?? 0;
        shares += (v['share_count'] as int?) ?? 0;
        collects += (v['collect_count'] as int?) ?? 0;

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
          } catch (e) {
            debugPrint('解析年龄分布失败: $e');
          }
        }

        final regionDistStr = (v['audience_region_dist'] as String?) ?? '';
        if (regionDistStr.isNotEmpty) {
          try {
            final regionMap = Map<String, double>.from(jsonDecode(regionDistStr));
            regionMap.forEach((key, value) {
              regionAgg[key] = (regionAgg[key] ?? 0) + value;
            });
            audienceDataCount++;
          } catch (e) {
            debugPrint('解析地区分布失败: $e');
          }
        }
      }

      if (maleRatioCount > 0) {
        _maleRatio = totalMaleRatio / maleRatioCount;
        _femaleRatio = 1 - _maleRatio;
      }

      if (ageAgg.isNotEmpty) {
        final total = ageAgg.values.fold<double>(0, (s, v) => s + v);
        _ageDistribution = ageAgg.map((k, v) => MapEntry(k, v / total));
        final sortedAge = _ageDistribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        if (sortedAge.isNotEmpty) {
          _coreAgeGroup = sortedAge.first.key;
          _coreAgeRatio = sortedAge.first.value;
        }
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
        _topRegion = _regionDistribution.first.key;
        _topRegionRatio = _regionDistribution.first.value;
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
        _collectRate = plays > 0 ? collects / plays * 100 : 0;
        _hasAudienceData = audienceDataCount > 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _runAiInterpretation() async {
    if (_aiInterpreting) return;
    setState(() => _aiInterpreting = true);
    try {
      final result = await AiService.instance.audienceInterpretation(
        maleRatio: _maleRatio,
        ageDistribution: _ageDistribution,
        topRegions: _regionDistribution,
        avgWatchDuration: _avgWatchDuration,
        avgFinishRate: _avgFinishRate,
      );
      if (!mounted) return;
      setState(() {
        _aiInterpretation = result;
        _aiInterpreting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiInterpretation = '分析失败: $e';
        _aiInterpreting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('粉丝画像'),
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
      return Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])));
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
        const SizedBox(height: 10),
        _buildEngagementRateCard(),
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
              Text('暂无粉丝画像数据', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
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
        _buildAudienceInsightCard(),
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
        const SizedBox(height: 10),
        _buildEngagementTipsCard(),
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
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.douyinRed, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Text('核心指标', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _metricBox('总播放', formatCount(_totalPlays), AppTheme.douyinRed)),
                const SizedBox(width: 6),
                Expanded(child: _metricBox('均完播率', '${_avgFinishRate.toStringAsFixed(1)}%', AppTheme.accentGreen)),
                const SizedBox(width: 6),
                Expanded(child: _metricBox('均观看时长', '${_avgWatchDuration.toStringAsFixed(1)}s', AppTheme.douyinCyan)),
                const SizedBox(width: 6),
                Expanded(child: _metricBox('视频数', '$_totalVideos', AppTheme.accentPurple)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
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
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.accentGreen, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Text('完播率分布', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            if (total == 0)
              Text('暂无完播率数据', style: TextStyle(color: Colors.grey[500]))
            else
              ...buckets.asMap().entries.map((entry) {
                final idx = entry.key;
                final bucket = entry.value;
                final ratio = bucket.value / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      SizedBox(width: 48, child: Text(bucket.key, style: const TextStyle(fontSize: 11))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 10,
                            backgroundColor: colors[idx].withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation(colors[idx]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(width: 28, child: Text(bucket.value.toString(), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementRateCard() {
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
                const Text('互动率概览', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _rateItem('点赞率', _likeRate, AppTheme.douyinRed)),
                Expanded(child: _rateItem('评论率', _commentRate, AppTheme.accentBlue)),
                Expanded(child: _rateItem('转发率', _shareRate, AppTheme.accentGreen)),
                Expanded(child: _rateItem('收藏率', _collectRate, AppTheme.accentAmber)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rateItem(String label, double value, Color color) {
    return Column(
      children: [
        Text('${value.toStringAsFixed(2)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildAiInterpretationCard() {
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
                const Expanded(child: Text('AI 粉丝画像解读', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                if (_aiInterpreting)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const Icon(Icons.auto_awesome, size: 14, color: AppTheme.accentPurple),
              ],
            ),
            if (_aiInterpretation != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_aiInterpretation!, style: const TextStyle(fontSize: 12, height: 1.6)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _aiInterpreting ? null : _runAiInterpretation, child: const Text('重新解读', style: TextStyle(fontSize: 11))),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text('AI 智能分析粉丝画像，告诉你受众是谁、喜欢什么内容', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _aiInterpreting ? null : _runAiInterpretation,
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('智能解读', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8), backgroundColor: AppTheme.accentPurple),
                ),
              ),
            ],
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
            const Text('性别分布', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 28,
                  sections: [
                    PieChartSectionData(
                      value: _maleRatio * 100,
                      color: AppTheme.accentBlue,
                      radius: 32,
                      title: '${(_maleRatio * 100).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: _femaleRatio * 100,
                      color: AppTheme.douyinRed,
                      radius: 32,
                      title: '${(_femaleRatio * 100).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dotLegend('男性', AppTheme.accentBlue),
                const SizedBox(width: 12),
                _dotLegend('女性', AppTheme.douyinRed),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dotLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildAgeCard() {
    final entries = _ageDistribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = entries.isNotEmpty ? entries.first.value : 1.0;
    final colors = [
      AppTheme.accentBlue,
      AppTheme.accentPurple,
      AppTheme.accentGreen,
      AppTheme.accentAmber,
      AppTheme.douyinRed,
      AppTheme.douyinCyan,
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('年龄分布', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('暂无年龄数据', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              )
            else
              Column(
                children: entries.take(5).map((e) {
                  final idx = entries.indexOf(e);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        SizedBox(width: 50, child: Text(e.key, style: const TextStyle(fontSize: 10))),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (e.value / maxVal).clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: colors[idx % colors.length].withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation(colors[idx % colors.length]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(width: 30, child: Text('${(e.value * 100).toStringAsFixed(1)}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceInsightCard() {
    final dominantGender = _maleRatio > 0.6
        ? '男性为主'
        : _femaleRatio > 0.6
            ? '女性为主'
            : '性别均衡';
    final genderColor = _maleRatio > 0.6
        ? AppTheme.accentBlue
        : _femaleRatio > 0.6
            ? AppTheme.douyinRed
            : AppTheme.accentPurple;

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
                const Text('核心受众特征', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _featureItem('性别特征', dominantGender, _maleRatio > _femaleRatio ? '${(_maleRatio * 100).toStringAsFixed(1)}%男性' : '${(_femaleRatio * 100).toStringAsFixed(1)}%女性', Icons.person_outline, genderColor),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _featureItem('核心年龄', _coreAgeGroup, '占比${(_coreAgeRatio * 100).toStringAsFixed(1)}%', Icons.cake_outlined, AppTheme.accentPurple),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _featureItem('TOP地区', _topRegion, '占比${(_topRegionRatio * 100).toStringAsFixed(1)}%', Icons.location_on_outlined, AppTheme.accentGreen),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _featureItem('完播率', '${_avgFinishRate.toStringAsFixed(1)}%', _avgFinishRate > 30 ? '表现优秀' : '有待提升', Icons.play_circle_outline, _avgFinishRate > 30 ? AppTheme.accentGreen : AppTheme.accentAmber),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureItem(String title, String main, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
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
          Text(main, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          Text(sub, style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildRegionCard() {
    final maxVal = _regionDistribution.isNotEmpty ? _regionDistribution.first.value : 1.0;
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
                const Text('地域分布 TOP10', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            if (_regionDistribution.isEmpty)
              Text('暂无地域数据', style: TextStyle(fontSize: 11, color: Colors.grey[500]))
            else
              ..._regionDistribution.take(10).toList().asMap().entries.map((entry) {
                final idx = entry.key;
                final region = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: idx < 3 ? AppTheme.accentAmber.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        alignment: Alignment.center,
                        child: Text('${idx + 1}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: idx < 3 ? AppTheme.accentAmber : Colors.grey[600])),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(width: 55, child: Text(region.key, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: (region.value / maxVal).clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: AppTheme.accentAmber.withOpacity(0.12),
                            valueColor: const AlwaysStoppedAnimation(AppTheme.accentAmber),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(width: 32, child: Text('${(region.value * 100).toStringAsFixed(1)}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementCard() {
    final rates = [
      _EngagementRate('点赞率', _likeRate, AppTheme.douyinRed, Icons.thumb_up_outlined),
      _EngagementRate('评论率', _commentRate, AppTheme.accentBlue, Icons.comment_outlined),
      _EngagementRate('转发率', _shareRate, AppTheme.accentGreen, Icons.share_outlined),
      _EngagementRate('收藏率', _collectRate, AppTheme.accentAmber, Icons.star_border),
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
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.douyinRed, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Text('互动率分析', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...rates.map((r) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(r.icon, size: 14, color: r.color),
                        const SizedBox(width: 6),
                        Text(r.label, style: const TextStyle(fontSize: 12)),
                        const Spacer(),
                        Text('${r.value.toStringAsFixed(2)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: r.color)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (r.value / 20).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: r.color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(r.color),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_getRateLevel(r.value), style: TextStyle(fontSize: 9, color: _getRateColor(r.value))),
                        Text('行业均值约 3-5%', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                      ],
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

  String _getRateLevel(double rate) {
    if (rate >= 8) return '表现优秀';
    if (rate >= 5) return '高于均值';
    if (rate >= 3) return '中等水平';
    return '有待提升';
  }

  Color _getRateColor(double rate) {
    if (rate >= 8) return AppTheme.accentGreen;
    if (rate >= 5) return AppTheme.accentBlue;
    if (rate >= 3) return AppTheme.accentAmber;
    return AppTheme.douyinRed;
  }

  Widget _buildEngagementTipsCard() {
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
                const Text('互动提升建议', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            _tipItem(Icons.question_mark, '引导互动', '视频结尾设置问题或投票，引导观众评论'),
            _tipItem(Icons.emoji_events, '制造争议', '选择有讨论空间的话题，激发评论区讨论'),
            _tipItem(Icons.star, '提供价值', '干货内容提升收藏率，让观众觉得有用'),
            _tipItem(Icons.share, '社交属性', '内容具有传播性，让观众愿意分享给朋友'),
          ],
        ),
      ),
    );
  }

  Widget _tipItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.accentBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EngagementRate {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  _EngagementRate(this.label, this.value, this.color, this.icon);
}
