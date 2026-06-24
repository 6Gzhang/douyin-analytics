import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../utils/video_quality_analyzer.dart';

class ViralGeneAnalysisPage extends ConsumerStatefulWidget {
  const ViralGeneAnalysisPage({super.key});

  @override
  ConsumerState<ViralGeneAnalysisPage> createState() => _ViralGeneAnalysisPageState();
}

class _ViralGeneAnalysisPageState extends ConsumerState<ViralGeneAnalysisPage> with SingleTickerProviderStateMixin {
  final _db = AppDatabase();
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  List<Map<String, dynamic>> _allVideos = [];
  List<Map<String, dynamic>> _topVideos = [];

  // 时长分析
  Map<String, dynamic> _durationAnalysis = {};
  // 发布时间分析
  Map<String, dynamic> _publishTimeAnalysis = {};
  // 完播率分布
  Map<String, dynamic> _finishRateAnalysis = {};
  // 互动率分析
  Map<String, dynamic> _interactionAnalysis = {};
  // 质量评分特征
  Map<String, dynamic> _qualityAnalysis = {};
  // 标题关键词
  List<_KeywordCount> _topKeywords = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double _getQualityScore(Map<String, dynamic> v) {
    return VideoQualityAnalyzer.calculateQualityScore(
      playCount: (v['play_count'] as int?) ?? 0,
      likeCount: (v['like_count'] as int?) ?? 0,
      commentCount: (v['comment_count'] as int?) ?? 0,
      shareCount: (v['share_count'] as int?) ?? 0,
      collectCount: (v['collect_count'] as int?) ?? 0,
      finishRate: (v['finish_rate'] as double?) ?? 0.0,
      avgWatchDuration: (v['avg_watch_duration'] as double?) ?? 0.0,
      fiveSecondFinishRate: (v['five_second_finish_rate'] as double?) ?? 0.0,
      twoSecondExitRate: (v['two_second_exit_rate'] as double?) ?? 0.0,
      coverCtr: (v['cover_ctr'] as double?) ?? 0.0,
      newFollowers: (v['new_followers'] as int?) ?? 0,
      duration: (v['duration'] as double?) ?? 0.0,
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await _db.getAllVideosWithMetrics();
      _allVideos = videos;

      if (videos.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      // 计算质量分
      final withScores = videos.map((v) {
        return {...v, 'quality_score': _getQualityScore(v)};
      }).toList();

      // 按播放排序
      withScores.sort((a, b) =>
          ((b['play_count'] as int?) ?? 0).compareTo((a['play_count'] as int?) ?? 0));

      final topCount = (withScores.length * 0.3).ceil();
      _topVideos = withScores.take(topCount).toList();

      // 1. 时长分析
      _analyzeDuration(withScores);

      // 2. 发布时间分析
      _analyzePublishTime(withScores);

      // 3. 完播率分析
      _analyzeFinishRate(withScores);

      // 4. 互动率分析
      _analyzeInteraction(withScores);

      // 5. 质量评分特征
      _analyzeQuality(withScores);

      // 6. 流量来源分析
      _analyzeTraffic(withScores);

      // 7. 标题关键词
      _analyzeKeywords(withScores);

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _analyzeDuration(List<Map<String, dynamic>> videos) {
    final topDurations = _topVideos.map((v) => (v['duration'] as double?) ?? 0.0).where((d) => d > 0).toList();
    final allDurations = videos.map((v) => (v['duration'] as double?) ?? 0.0).where((d) => d > 0).toList();

    double avgTop = topDurations.isNotEmpty ? topDurations.reduce((a, b) => a + b) / topDurations.length : 0;
    double avgAll = allDurations.isNotEmpty ? allDurations.reduce((a, b) => a + b) / allDurations.length : 0;

    // 时长区间
    final ranges = [
      {'label': '0-15s', 'min': 0, 'max': 15},
      {'label': '15-30s', 'min': 15, 'max': 30},
      {'label': '30-60s', 'min': 30, 'max': 60},
      {'label': '1-3min', 'min': 60, 'max': 180},
      {'label': '3min+', 'min': 180, 'max': 99999},
    ];

    List<Map<String, dynamic>> rangeData = [];
    for (final range in ranges) {
      final minVal = (range['min'] as num).toDouble();
      final maxVal = (range['max'] as num).toDouble();
      final topInRange = topDurations.where((d) => d >= minVal && d < maxVal).length;
      final allInRange = allDurations.where((d) => d >= minVal && d < maxVal).length;
      rangeData.add({
        'label': range['label'],
        'topCount': topInRange,
        'allCount': allInRange,
        'topRatio': topDurations.isNotEmpty ? topInRange / topDurations.length : 0,
        'allRatio': allDurations.isNotEmpty ? allInRange / allDurations.length : 0,
      });
    }

    _durationAnalysis = {
      'avgTop': avgTop,
      'avgAll': avgAll,
      'bestRange': rangeData.reduce((a, b) => a['topRatio'] > b['topRatio'] ? a : b),
      'ranges': rangeData,
    };
  }

  void _analyzePublishTime(List<Map<String, dynamic>> videos) {
    // 小时分布
    final topHours = List<int>.filled(24, 0);
    final allHours = List<int>.filled(24, 0);

    for (final v in _topVideos) {
      final ct = v['create_time'] as int?;
      if (ct != null && ct > 0) {
        final hour = DateTime.fromMillisecondsSinceEpoch(ct * 1000).hour;
        topHours[hour]++;
      }
    }
    for (final v in videos) {
      final ct = v['create_time'] as int?;
      if (ct != null && ct > 0) {
        final hour = DateTime.fromMillisecondsSinceEpoch(ct * 1000).hour;
        allHours[hour]++;
      }
    }

    // 星期分布
    final topWeekdays = List<int>.filled(7, 0);
    final allWeekdays = List<int>.filled(7, 0);
    const weekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    for (final v in _topVideos) {
      final ct = v['create_time'] as int?;
      if (ct != null && ct > 0) {
        final wd = DateTime.fromMillisecondsSinceEpoch(ct * 1000).weekday - 1;
        topWeekdays[wd]++;
      }
    }
    for (final v in videos) {
      final ct = v['create_time'] as int?;
      if (ct != null && ct > 0) {
        final wd = DateTime.fromMillisecondsSinceEpoch(ct * 1000).weekday - 1;
        allWeekdays[wd]++;
      }
    }

    // 找出最佳发布小时
    int bestHour = 0;
    double bestHourRatio = 0;
    for (int i = 0; i < 24; i++) {
      if (topHours[i] > 0 && _topVideos.isNotEmpty) {
        final ratio = topHours[i] / _topVideos.length;
        if (ratio > bestHourRatio) {
          bestHourRatio = ratio;
          bestHour = i;
        }
      }
    }

    // 找出最佳星期
    int bestWeekday = 0;
    double bestWeekdayRatio = 0;
    for (int i = 0; i < 7; i++) {
      if (topWeekdays[i] > 0 && _topVideos.isNotEmpty) {
        final ratio = topWeekdays[i] / _topVideos.length;
        if (ratio > bestWeekdayRatio) {
          bestWeekdayRatio = ratio;
          bestWeekday = i;
        }
      }
    }

    _publishTimeAnalysis = {
      'topHours': topHours,
      'allHours': allHours,
      'topWeekdays': topWeekdays,
      'allWeekdays': allWeekdays,
      'weekdayLabels': weekdayLabels,
      'bestHour': bestHour,
      'bestHourRatio': bestHourRatio,
      'bestWeekday': bestWeekday,
      'bestWeekdayLabel': weekdayLabels[bestWeekday],
      'bestWeekdayRatio': bestWeekdayRatio,
    };
  }

  void _analyzeFinishRate(List<Map<String, dynamic>> videos) {
    final topFR = _topVideos.map((v) => (v['finish_rate'] as double?) ?? 0.0).where((d) => d > 0).toList();
    final allFR = videos.map((v) => (v['finish_rate'] as double?) ?? 0.0).where((d) => d > 0).toList();

    double avgTop = topFR.isNotEmpty ? topFR.reduce((a, b) => a + b) / topFR.length : 0;
    double avgAll = allFR.isNotEmpty ? allFR.reduce((a, b) => a + b) / allFR.length : 0;

    final ranges = [
      {'label': '<20%', 'min': 0, 'max': 20},
      {'label': '20-30%', 'min': 20, 'max': 30},
      {'label': '30-40%', 'min': 30, 'max': 40},
      {'label': '40-50%', 'min': 40, 'max': 50},
      {'label': '50%+', 'min': 50, 'max': 100},
    ];

    List<Map<String, dynamic>> rangeData = [];
    for (final range in ranges) {
      final minVal = (range['min'] as num).toDouble();
      final maxVal = (range['max'] as num).toDouble();
      final topInRange = topFR.where((d) => d >= minVal && d < maxVal).length;
      rangeData.add({
        'label': range['label'],
        'topCount': topInRange,
        'topRatio': topFR.isNotEmpty ? topInRange / topFR.length : 0,
      });
    }

    _finishRateAnalysis = {
      'avgTop': avgTop,
      'avgAll': avgAll,
      'diff': avgTop - avgAll,
      'ranges': rangeData,
    };
  }

  void _analyzeInteraction(List<Map<String, dynamic>> videos) {
    double calcInt(Map<String, dynamic> v) {
      final plays = (v['play_count'] as int?) ?? 0;
      if (plays == 0) return 0;
      final likes = (v['like_count'] as int?) ?? 0;
      final comments = (v['comment_count'] as int?) ?? 0;
      final shares = (v['share_count'] as int?) ?? 0;
      final collects = (v['collect_count'] as int?) ?? 0;
      return (likes + comments + shares + collects) / plays * 100;
    }

    final topInt = _topVideos.map(calcInt).where((d) => d > 0).toList();
    final allInt = videos.map(calcInt).where((d) => d > 0).toList();

    double avgTop = topInt.isNotEmpty ? topInt.reduce((a, b) => a + b) / topInt.length : 0;
    double avgAll = allInt.isNotEmpty ? allInt.reduce((a, b) => a + b) / allInt.length : 0;

    // 点赞率
    final topLikeRate = _topVideos.map((v) => (v['like_rate'] as double?) ?? 0.0).where((d) => d > 0).toList();
    final topCommentRate = _topVideos.map((v) => (v['comment_rate'] as double?) ?? 0.0).where((d) => d > 0).toList();
    final topShareRate = _topVideos.map((v) => (v['share_rate'] as double?) ?? 0.0).where((d) => d > 0).toList();

    _interactionAnalysis = {
      'avgTop': avgTop,
      'avgAll': avgAll,
      'diff': avgTop - avgAll,
      'avgLikeRate': topLikeRate.isNotEmpty ? topLikeRate.reduce((a, b) => a + b) / topLikeRate.length : 0,
      'avgCommentRate': topCommentRate.isNotEmpty ? topCommentRate.reduce((a, b) => a + b) / topCommentRate.length : 0,
      'avgShareRate': topShareRate.isNotEmpty ? topShareRate.reduce((a, b) => a + b) / topShareRate.length : 0,
    };
  }

  void _analyzeQuality(List<Map<String, dynamic>> videos) {
    final topScores = _topVideos.map((v) => (v['quality_score'] as num).toDouble()).toList();
    final allScores = videos.map((v) => (v['quality_score'] as num).toDouble()).toList();

    double avgTop = topScores.isNotEmpty ? topScores.reduce((a, b) => a + b) / topScores.length : 0;
    double avgAll = allScores.isNotEmpty ? allScores.reduce((a, b) => a + b) / allScores.length : 0;

    // 等级分布
    final grades = ['S', 'A', 'B', 'C', 'D'];
    final gradeCounts = <String, int>{};
    for (final g in grades) {
      gradeCounts[g] = 0;
    }

    for (final v in _topVideos) {
      final qualityScore = (v['quality_score'] as num).toDouble();
      final grade = VideoQualityAnalyzer.getQualityGrade(qualityScore);
      final gradeKey = grade.name.toUpperCase();
      gradeCounts[gradeKey] = (gradeCounts[gradeKey] ?? 0) + 1;
    }

    _qualityAnalysis = {
      'avgTop': avgTop,
      'avgAll': avgAll,
      'diff': avgTop - avgAll,
      'gradeCounts': gradeCounts,
      'topGrade': gradeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key,
    };
  }

  void _analyzeTraffic(List<Map<String, dynamic>> videos) {
    double avgRecommend = 0, avgSearch = 0, avgFollow = 0, avgCity = 0;
    int count = 0;

    for (final v in _topVideos) {
      final r = (v['traffic_recommend'] as double?) ?? 0;
      final s = (v['traffic_search'] as double?) ?? 0;
      final f = (v['traffic_follow'] as double?) ?? 0;
      final c = (v['traffic_city'] as double?) ?? 0;
      if (r > 0 || s > 0 || f > 0 || c > 0) {
        avgRecommend += r;
        avgSearch += s;
        avgFollow += f;
        avgCity += c;
        count++;
      }
    }

    if (count > 0) {
      avgRecommend /= count;
      avgSearch /= count;
      avgFollow /= count;
      avgCity /= count;
    }
  }

  void _analyzeKeywords(List<Map<String, dynamic>> videos) {
    final keywordCount = <String, int>{};
    final stopWords = {'的', '了', '是', '在', '我', '有', '和', '就', '不', '人', '都', '一', '一个', '上', '也', '很', '到', '说', '要', '去', '你', '会', '着', '没有', '看', '好', '自己', '这'};

    for (final v in _topVideos) {
      final title = v['title'] as String? ?? '';
      // 简单分词：按常见分隔符和2-4字组合
      final words = <String>[];

      // 提取2字词
      for (int i = 0; i < title.length - 1; i++) {
        final w = title.substring(i, i + 2);
        if (!stopWords.contains(w) && !w.contains(' ') && !w.contains('\n')) {
          words.add(w);
        }
      }

      // 提取3字词
      for (int i = 0; i < title.length - 2; i++) {
        final w = title.substring(i, i + 3);
        if (!stopWords.contains(w)) {
          words.add(w);
        }
      }

      for (final w in words) {
        keywordCount[w] = (keywordCount[w] ?? 0) + 1;
      }
    }

    final sorted = keywordCount.entries
        .where((e) => e.value >= 2)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _topKeywords = sorted.take(20).map((e) => _KeywordCount(e.key, e.value)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('爆款基因分析'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '时长基因'),
            Tab(text: '发布时机'),
            Tab(text: '完播特征'),
            Tab(text: '互动特征'),
            Tab(text: '质量分布'),
            Tab(text: '标题关键词'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _allVideos.isEmpty
                  ? _buildEmpty()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDurationTab(),
                        _buildPublishTimeTab(),
                        _buildFinishRateTab(),
                        _buildInteractionTab(),
                        _buildQualityTab(),
                        _buildKeywordsTab(),
                      ],
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('加载失败', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(
              _error ?? '未知错误',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('暂无数据', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('导入视频数据后即可分析爆款基因', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, String desc, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildDurationTab() {
    final best = _durationAnalysis['bestRange'];
    final bestLabel = best != null ? best['label'] : '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  '爆款平均时长',
                  _durationAnalysis['avgTop'] != null
                      ? '${_durationAnalysis['avgTop'].toStringAsFixed(0)}秒'
                      : '-',
                  '高播放视频平均时长',
                  AppTheme.douyinRed,
                  Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  '整体平均时长',
                  _durationAnalysis['avgAll'] != null
                      ? '${_durationAnalysis['avgAll'].toStringAsFixed(0)}秒'
                      : '-',
                  '全部视频平均时长',
                  Colors.grey,
                  Icons.timer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  '最佳时长区间',
                  bestLabel,
                  '爆款视频最集中',
                  Color(0xFF4CAF50),
                  Icons.star_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('时长区间分布（爆款 vs 全部）'),
          const SizedBox(height: 12),
          _buildDistributionChart(_durationAnalysis['ranges'] ?? []),
        ],
      ),
    );
  }

  Widget _buildPublishTimeTab() {
    final bestHour = _publishTimeAnalysis['bestHour'] ?? 0;
    final bestHourRatio = _publishTimeAnalysis['bestHourRatio'] ?? 0.0;
    final bestWeekday = _publishTimeAnalysis['bestWeekdayLabel'] ?? '-';
    final bestWeekdayRatio = _publishTimeAnalysis['bestWeekdayRatio'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  '最佳发布小时',
                  '$bestHour:00',
                  '${(bestHourRatio * 100).toStringAsFixed(1)}% 爆款在此时段',
                  AppTheme.douyinRed,
                  Icons.access_time,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  '最佳发布星期',
                  bestWeekday,
                  '${(bestWeekdayRatio * 100).toStringAsFixed(1)}% 爆款在这天',
                  Color(0xFF4CAF50),
                  Icons.calendar_today,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('24小时发布分布'),
          const SizedBox(height: 12),
          _buildHourChart(),
          const SizedBox(height: 20),
          _buildSectionTitle('星期发布分布'),
          const SizedBox(height: 12),
          _buildWeekdayChart(),
        ],
      ),
    );
  }

  Widget _buildFinishRateTab() {
    final avgTop = _finishRateAnalysis['avgTop'] ?? 0.0;
    final avgAll = _finishRateAnalysis['avgAll'] ?? 0.0;
    final diff = _finishRateAnalysis['diff'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  '爆款平均完播率',
                  '${avgTop.toStringAsFixed(1)}%',
                  '高播放视频完播率',
                  AppTheme.douyinRed,
                  Icons.playlist_play,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  '整体平均完播率',
                  '${avgAll.toStringAsFixed(1)}%',
                  '全部视频完播率',
                  Colors.grey,
                  Icons.play_circle_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  '差距',
                  '+${diff.toStringAsFixed(1)}%',
                  '爆款比整体高出',
                  Color(0xFF4CAF50),
                  Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('爆款视频完播率区间分布'),
          const SizedBox(height: 12),
          _buildFinishRateDistribution(),
        ],
      ),
    );
  }

  Widget _buildInteractionTab() {
    final avgTop = _interactionAnalysis['avgTop'] ?? 0.0;
    final avgAll = _interactionAnalysis['avgAll'] ?? 0.0;
    final avgLike = _interactionAnalysis['avgLikeRate'] ?? 0.0;
    final avgComment = _interactionAnalysis['avgCommentRate'] ?? 0.0;
    final avgShare = _interactionAnalysis['avgShareRate'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  '爆款平均互动率',
                  '${avgTop.toStringAsFixed(2)}%',
                  '点赞+评论+分享+收藏',
                  AppTheme.douyinRed,
                  Icons.favorite_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  '整体平均互动率',
                  '${avgAll.toStringAsFixed(2)}%',
                  '全部视频互动率',
                  Colors.grey,
                  Icons.favorite_border,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  '平均点赞率',
                  '${avgLike.toStringAsFixed(2)}%',
                  '爆款视频点赞率',
                  Colors.red[400]!,
                  Icons.thumb_up_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  '平均评论率',
                  '${avgComment.toStringAsFixed(2)}%',
                  '爆款视频评论率',
                  Colors.blue[400]!,
                  Icons.comment_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  '平均分享率',
                  '${avgShare.toStringAsFixed(2)}%',
                  '爆款视频分享率',
                  Colors.green[400]!,
                  Icons.share_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('互动维度拆解'),
          const SizedBox(height: 12),
          _buildInteractionBreakdown(avgLike, avgComment, avgShare),
        ],
      ),
    );
  }

  Widget _buildQualityTab() {
    final avgTop = _qualityAnalysis['avgTop'] ?? 0.0;
    final avgAll = _qualityAnalysis['avgAll'] ?? 0.0;
    final topGrade = _qualityAnalysis['topGrade'] ?? '-';
    final gradeCounts = _qualityAnalysis['gradeCounts'] as Map<String, int>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  '爆款平均质量分',
                  avgTop.toStringAsFixed(1),
                  '高播放视频质量评分',
                  AppTheme.douyinRed,
                  Icons.star_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  '整体平均质量分',
                  avgAll.toStringAsFixed(1),
                  '全部视频质量评分',
                  Colors.grey,
                  Icons.star_border,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  '爆款主力等级',
                  topGrade,
                  '爆款视频最多的等级',
                  _gradeColor(topGrade),
                  Icons.emoji_events_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('爆款视频质量等级分布'),
          const SizedBox(height: 12),
          _buildGradeDistribution(gradeCounts),
        ],
      ),
    );
  }

  Widget _buildKeywordsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('爆款标题高频词 TOP 20'),
          const SizedBox(height: 12),
          if (_topKeywords.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('数据不足，无法提取关键词', style: TextStyle(color: Colors.grey[500])),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _topKeywords.asMap().entries.map((entry) {
                final idx = entry.key;
                final kw = entry.value;
                final maxCount = _topKeywords.first.count;
                final size = 12.0 + (kw.count / maxCount) * 8;
                final color = idx < 3 ? AppTheme.douyinRed : idx < 8 ? Colors.orange : Colors.grey[700];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (idx < 3 ? AppTheme.douyinRed : idx < 8 ? Colors.orange : Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (idx < 3 ? AppTheme.douyinRed : idx < 8 ? Colors.orange : Colors.grey).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (idx < 3)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.star, size: 14, color: idx < 3 ? AppTheme.douyinRed : Colors.orange),
                        ),
                      Text(kw.keyword, style: TextStyle(fontSize: size, fontWeight: idx < 5 ? FontWeight.bold : FontWeight.w500, color: color)),
                      const SizedBox(width: 4),
                      Text('×${kw.count}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          _buildSectionTitle('爆款标题特征'),
          const SizedBox(height: 12),
          _buildTitleInsights(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildDistributionChart(List<dynamic> ranges) {
    return Column(
      children: ranges.map((r) {
        final topRatio = (r['topRatio'] as double?) ?? 0.0;
        final allRatio = (r['allRatio'] as double?) ?? 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(width: 60, child: Text(r['label'], style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('爆款', style: TextStyle(fontSize: 10, color: AppTheme.douyinRed)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: topRatio,
                              backgroundColor: AppTheme.douyinRed.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation(AppTheme.douyinRed),
                              minHeight: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${(topRatio * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: AppTheme.douyinRed, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('全部', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: allRatio,
                              backgroundColor: Colors.grey.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation(Colors.grey[400]!),
                              minHeight: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${(allRatio * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHourChart() {
    final topHours = _publishTimeAnalysis['topHours'] as List<int>? ?? [];
    if (topHours.isEmpty) return const SizedBox();

    final maxVal = topHours.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxVal == 0) return const SizedBox();

    return SizedBox(
      height: 160,
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
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  if (value % 6 == 0) {
                    return Text('${value.toInt()}时', style: TextStyle(fontSize: 10, color: Colors.grey[500]));
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(24, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: topHours[i].toDouble(),
                  color: i == (_publishTimeAnalysis['bestHour'] ?? 0) ? AppTheme.douyinRed : Colors.blue.withOpacity(0.5),
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildWeekdayChart() {
    final topWeekdays = _publishTimeAnalysis['topWeekdays'] as List<int>? ?? [];
    final labels = _publishTimeAnalysis['weekdayLabels'] as List<String>? ?? [];
    if (topWeekdays.isEmpty) return const SizedBox();

    final maxVal = topWeekdays.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxVal == 0) return const SizedBox();

    return SizedBox(
      height: 160,
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
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < labels.length) {
                    return Text(labels[idx], style: TextStyle(fontSize: 11, color: Colors.grey[600]));
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: topWeekdays[i].toDouble(),
                  color: i == (_publishTimeAnalysis['bestWeekday'] ?? 0) ? Color(0xFF4CAF50) : Colors.blue.withOpacity(0.5),
                  width: 24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildFinishRateDistribution() {
    final ranges = _finishRateAnalysis['ranges'] as List<dynamic>? ?? [];
    return Column(
      children: ranges.map((r) {
        final ratio = (r['topRatio'] as double?) ?? 0.0;
        final count = r['topCount'] as int? ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(width: 60, child: Text(r['label'], style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: AppTheme.douyinRed.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation(AppTheme.douyinRed),
                    minHeight: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$count条 (${(ratio * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, color: AppTheme.douyinRed, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInteractionBreakdown(double like, double comment, double share) {
    final total = like + comment + share;
    if (total == 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _breakdownItem('点赞率', like, total, Colors.red[400]!),
          ),
          Expanded(
            child: _breakdownItem('评论率', comment, total, Colors.blue[400]!),
          ),
          Expanded(
            child: _breakdownItem('分享率', share, total, Colors.green[400]!),
          ),
        ],
      ),
    );
  }

  Widget _breakdownItem(String label, double value, double total, Color color) {
    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(2)}%',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 8),
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            value: total > 0 ? value / total : 0,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
            strokeWidth: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildGradeDistribution(Map<String, int> counts) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox();

    final grades = ['S', 'A', 'B', 'C', 'D'];
    return Column(
      children: grades.map((g) {
        final count = counts[g] ?? 0;
        final ratio = total > 0 ? count / total : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _gradeColor(g),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(g, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: _gradeColor(g).withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(_gradeColor(g)),
                    minHeight: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$count条 (${(ratio * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 11, color: _gradeColor(g), fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTitleInsights() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: Colors.orange),
              const SizedBox(width: 6),
              const Text('爆款标题规律', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          _insightRow('1', '关键词前置', '把最吸引人的词放在标题前10个字'),
          _insightRow('2', '制造悬念', '用"为什么""你绝对想不到"等勾起好奇心'),
          _insightRow('3', '数字标题', '包含具体数字的标题更容易点击'),
          _insightRow('4', '情绪共鸣', '触动用户情绪的标题更容易被分享'),
          _insightRow('5', '热点结合', '结合当下热点话题更容易获得推荐流量'),
        ],
      ),
    );
  }

  Widget _insightRow(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(num, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'S': return const Color(0xFF9C27B0);
      case 'A': return const Color(0xFF4CAF50);
      case 'B': return const Color(0xFF2196F3);
      case 'C': return const Color(0xFFFF9800);
      case 'D': return const Color(0xFFF44336);
      default: return Colors.grey;
    }
  }
}

class _KeywordCount {
  final String keyword;
  final int count;

  _KeywordCount(this.keyword, this.count);
}
