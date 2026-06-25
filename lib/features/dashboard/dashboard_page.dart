import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../services/ai_service.dart';
import '../../services/update_service.dart';
import '../../utils/video_quality_analyzer.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with SingleTickerProviderStateMixin {
  final _db = AppDatabase();
  bool _loading = true;
  String? _error;

  // 基础数据
  int _totalVideos = 0;
  int _totalPlays = 0;
  int _totalLikes = 0;
  int _totalComments = 0;
  int _totalShares = 0;
  int _totalCollects = 0;
  int _totalNewFollowers = 0;

  // 平均值
  double _avgPlays = 0.0;
  double _avgFinishRate = 0.0;
  double _avgFiveSecFinish = 0.0;
  double _avgCoverCtr = 0.0;
  double _avgWatchDuration = 0.0;
  double _avgTwoSecExitRate = 0.0;

  // 衍生指标
  double _likeRate = 0.0;
  double _commentRate = 0.0;
  double _shareRate = 0.0;
  double _collectRate = 0.0;
  double _interactionRate = 0.0;

  // 质量评分
  double _avgQualityScore = 0.0;
  QualityGrade _avgQualityGrade = QualityGrade.c;
  int _sGradeCount = 0;
  int _aGradeCount = 0;
  int _bGradeCount = 0;
  int _cGradeCount = 0;
  int _dGradeCount = 0;

  // 流量来源
  double _trafficRecommend = 0.0;
  double _trafficSearch = 0.0;
  double _trafficFollow = 0.0;
  double _trafficCity = 0.0;
  bool _hasTrafficData = false;

  // 视频列表
  List<Map<String, dynamic>> _topVideos = [];
  List<Map<String, dynamic>> _lowQualityVideos = [];
  bool _hasData = false;

  // AI诊断
  String? _channelDiagnosisResult;
  bool _diagnosisLoading = false;

  // 发布时间分析
  Map<int, double> _hourPerformance = {};
  Map<int, double> _weekdayPerformance = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _checkUpdateOnStartup();
  }

  Future<void> _checkUpdateOnStartup() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final currentVersion = await UpdateService.getCurrentVersion();
    final latest = await UpdateService.checkForUpdate(currentVersion);
    if (latest != null && mounted) {
      _showUpdateDialog(latest);
    }
  }

  void _showUpdateDialog(AppVersion version) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.update, color: AppTheme.primaryColor, size: 22),
            SizedBox(width: 8),
            Text('发现新版本'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最新版本: v${version.version}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (version.releaseNotes != null && version.releaseNotes!.isNotEmpty) ...[
              const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  version.releaseNotes!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () async {
              final url = version.downloadUrl ??
                  'https://github.com/6Gzhang/-/releases/latest';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('前往下载'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final videos = await _db.getAllVideosWithMetrics();
      final traffic = await _db.getTrafficSourceAvg();

      if (videos.isEmpty) {
        setState(() {
          _loading = false;
          _hasData = false;
        });
        return;
      }

      _totalVideos = videos.length;

      int totalPlays = 0, totalLikes = 0, totalComments = 0;
      int totalShares = 0, totalCollects = 0, totalNewFollowers = 0;
      double totalFinish = 0, totalWatch = 0, total5s = 0, total2s = 0, totalCover = 0;
      int finishCount = 0, watchCount = 0, count5s = 0, count2s = 0, coverCount = 0;
      double totalQualityScore = 0;
      int qualityCount = 0;

      // 质量评分统计
      int sCount = 0, aCount = 0, bCount = 0, cCount = 0, dCount = 0;

      for (final v in videos) {
        final plays = (v['play_count'] as int?) ?? 0;
        final likes = (v['like_count'] as int?) ?? 0;
        final comments = (v['comment_count'] as int?) ?? 0;
        final shares = (v['share_count'] as int?) ?? 0;
        final collects = (v['collect_count'] as int?) ?? 0;
        final newFollowers = (v['new_followers'] as int?) ?? 0;
        final finish = (v['finish_rate'] as double?) ?? 0.0;
        final watch = (v['avg_watch_duration'] as double?) ?? 0.0;
        final fiveSec = (v['five_second_finish_rate'] as double?) ?? 0.0;
        final twoSec = (v['two_second_exit_rate'] as double?) ?? 0.0;
        final ctr = (v['cover_ctr'] as double?) ?? 0.0;
        final duration = (v['duration'] as double?) ?? 0.0;

        totalPlays += plays;
        totalLikes += likes;
        totalComments += comments;
        totalShares += shares;
        totalCollects += collects;
        totalNewFollowers += newFollowers;

        if (finish > 0) { totalFinish += finish; finishCount++; }
        if (watch > 0) { totalWatch += watch; watchCount++; }
        if (fiveSec > 0) { total5s += fiveSec; count5s++; }
        if (twoSec > 0) { total2s += twoSec; count2s++; }
        if (ctr > 0) { totalCover += ctr; coverCount++; }

        // 计算质量评分
        if (plays > 0) {
          final score = VideoQualityAnalyzer.calculateQualityScore(
            playCount: plays,
            likeCount: likes,
            commentCount: comments,
            shareCount: shares,
            collectCount: collects,
            finishRate: finish,
            avgWatchDuration: watch,
            fiveSecondFinishRate: fiveSec,
            twoSecondExitRate: twoSec,
            coverCtr: ctr,
            newFollowers: newFollowers,
            duration: duration,
          );
          totalQualityScore += score;
          qualityCount++;

          final grade = VideoQualityAnalyzer.getQualityGrade(score);
          switch (grade) {
            case QualityGrade.s: sCount++; break;
            case QualityGrade.a: aCount++; break;
            case QualityGrade.b: bCount++; break;
            case QualityGrade.c: cCount++; break;
            case QualityGrade.d: dCount++; break;
          }
        }
      }

      _totalPlays = totalPlays;
      _totalLikes = totalLikes;
      _totalComments = totalComments;
      _totalShares = totalShares;
      _totalCollects = totalCollects;
      _totalNewFollowers = totalNewFollowers;

      _avgPlays = totalPlays / _totalVideos;
      _avgFinishRate = finishCount > 0 ? totalFinish / finishCount : 0;
      _avgFiveSecFinish = count5s > 0 ? total5s / count5s : 0;
      _avgCoverCtr = coverCount > 0 ? totalCover / coverCount : 0;
      _avgWatchDuration = watchCount > 0 ? totalWatch / watchCount : 0;
      _avgTwoSecExitRate = count2s > 0 ? total2s / count2s : 0;

      _likeRate = totalPlays > 0 ? totalLikes / totalPlays : 0;
      _commentRate = totalPlays > 0 ? totalComments / totalPlays : 0;
      _shareRate = totalPlays > 0 ? totalShares / totalPlays : 0;
      _collectRate = totalPlays > 0 ? totalCollects / totalPlays : 0;
      _interactionRate = totalPlays > 0
          ? (totalLikes + totalComments + totalShares + totalCollects) / totalPlays
          : 0;

      _avgQualityScore = qualityCount > 0 ? totalQualityScore / qualityCount : 0;
      _avgQualityGrade = VideoQualityAnalyzer.getQualityGrade(_avgQualityScore);
      _sGradeCount = sCount;
      _aGradeCount = aCount;
      _bGradeCount = bCount;
      _cGradeCount = cCount;
      _dGradeCount = dCount;

      // 流量来源
      _trafficRecommend = traffic['recommend'] ?? 0.0;
      _trafficSearch = traffic['search'] ?? 0.0;
      _trafficFollow = traffic['follow'] ?? 0.0;
      _trafficCity = traffic['city'] ?? 0.0;
      _hasTrafficData = _trafficRecommend > 0 || _trafficSearch > 0;

      // 排序
      final sortedByPlays = List<Map<String, dynamic>>.from(videos)
        ..sort((a, b) =>
            (b['play_count'] as int? ?? 0).compareTo(a['play_count'] as int? ?? 0));

      final sortedByQuality = List<Map<String, dynamic>>.from(videos)
        .where((v) => (v['play_count'] as int? ?? 0) > 0)
        .toList()
        ..sort((a, b) {
          final scoreA = _calcVideoScore(a);
          final scoreB = _calcVideoScore(b);
          return scoreB.compareTo(scoreA);
        });

      _topVideos = sortedByPlays.take(5).toList();
      _lowQualityVideos = sortedByQuality.reversed.take(5).toList().reversed.toList();

      // 发布时间分析
      _hourPerformance = VideoQualityAnalyzer.analyzePublishHourPerformance(videos);
      _weekdayPerformance = VideoQualityAnalyzer.analyzePublishWeekdayPerformance(videos);

      _hasData = true;
      _loading = false;
      setState(() {});

    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double _calcVideoScore(Map<String, dynamic> v) {
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

  Future<void> _runDiagnosis() async {
    setState(() => _diagnosisLoading = true);
    try {
      final stats = await _db.getChannelStats();
      final result = await AiService.instance.channelDiagnosis(stats);
      setState(() => _channelDiagnosisResult = result);
    } catch (e) {
      setState(() => _channelDiagnosisResult = '诊断失败: ${e.toString()}');
    } finally {
      setState(() => _diagnosisLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('加载失败: $_error'))
              : !_hasData
                  ? _buildEmptyState()
                  : _buildDashboard(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('暂无数据', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('请先导入视频数据', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/data-import'),
            child: const Text('去导入数据'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 版本号
            Row(
              children: [
                Text(
                  "数据总览",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "v1.1.0",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 顶部质量总览卡
            _buildQualityOverviewCard(),
            const SizedBox(height: 12),

            // 核心数据 - 2x3 网格
            _buildCoreMetricsGrid(),
            const SizedBox(height: 12),

            // 质量分布 + 流量来源 (并排)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildQualityDistributionCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildTrafficSourceCard()),
              ],
            ),
            const SizedBox(height: 12),

            // AI频道诊断
            _buildDiagnosisCard(),
            const SizedBox(height: 12),

            // 发布时间分析
            _buildPublishTimeAnalysisCard(),
            const SizedBox(height: 12),

            // 双列视频列表
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTopVideosCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildLowQualityCard()),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ========== 质量总览卡 ==========
  Widget _buildQualityOverviewCard() {
    final gradeColor = Color(VideoQualityAnalyzer.getGradeColor(_avgQualityGrade));
    final gradeText = VideoQualityAnalyzer.getGradeText(_avgQualityGrade);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradeColor.withOpacity(0.15),
            gradeColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gradeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 质量评分大数字
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gradeColor.withOpacity(0.2),
                  border: Border.all(color: gradeColor, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _avgQualityScore.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: gradeColor,
                      ),
                    ),
                    Text(
                      '综合评分',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: gradeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            gradeText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '账号整体质量',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildMiniStat('总播放', _formatK(_totalPlays.toDouble())),
                        _buildMiniStat('总点赞', _formatK(_totalLikes.toDouble())),
                        _buildMiniStat('总评论', _formatK(_totalComments.toDouble())),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildMiniStat('总分享', _formatK(_totalShares.toDouble())),
                        _buildMiniStat('总收藏', _formatK(_totalCollects.toDouble())),
                        _buildMiniStat('涨粉', _formatK(_totalNewFollowers.toDouble())),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ========== 核心指标网格 ==========
  Widget _buildCoreMetricsGrid() {
    final metrics = [
      {'label': '平均播放', 'value': _formatK(_avgPlays), 'icon': Icons.play_circle, 'color': Colors.blue},
      {'label': '互动率', 'value': _pct(_interactionRate), 'icon': Icons.favorite, 'color': Colors.pink},
      {'label': '完播率', 'value': _pct(_avgFinishRate), 'icon': Icons.visibility, 'color': Colors.green},
      {'label': '5秒完播', 'value': _pct(_avgFiveSecFinish), 'icon': Icons.timer, 'color': Colors.orange},
      {'label': '平均观看', 'value': '${_avgWatchDuration.toStringAsFixed(1)}s', 'icon': Icons.timer_outlined, 'color': Colors.cyan},
      {'label': '2秒跳出', 'value': _pct(_avgTwoSecExitRate), 'icon': Icons.exit_to_app, 'color': Colors.red},
      {'label': '点赞率', 'value': _pct(_likeRate), 'icon': Icons.thumb_up, 'color': Colors.redAccent},
      {'label': '评论率', 'value': _pct(_commentRate), 'icon': Icons.comment, 'color': Colors.purple},
      {'label': '分享率', 'value': _pct(_shareRate), 'icon': Icons.share, 'color': Colors.teal},
      {'label': '收藏率', 'value': _pct(_collectRate), 'icon': Icons.bookmark, 'color': Colors.amber},
      {'label': '封面CTR', 'value': _pct(_avgCoverCtr), 'icon': Icons.image, 'color': Colors.indigo},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.6,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final m = metrics[index];
        return _buildMetricCard(
          icon: m['icon'] as IconData,
          label: m['label'] as String,
          value: m['value'] as String,
          color: m['color'] as Color,
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ========== 质量分布卡 ==========
  Widget _buildQualityDistributionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, size: 16, color: AppTheme.accentBlue),
                SizedBox(width: 6),
                Text('质量分布', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            _buildGradeBar('S 爆款', _sGradeCount, Colors.red),
            const SizedBox(height: 6),
            _buildGradeBar('A 优秀', _aGradeCount, Colors.amber),
            const SizedBox(height: 6),
            _buildGradeBar('B 良好', _bGradeCount, Colors.green),
            const SizedBox(height: 6),
            _buildGradeBar('C 一般', _cGradeCount, Colors.blue),
            const SizedBox(height: 6),
            _buildGradeBar('D 待优化', _dGradeCount, Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeBar(String label, int count, Color color) {
    final maxCount = max(1, _totalVideos);
    final ratio = count / maxCount;

    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ========== 流量来源卡 ==========
  Widget _buildTrafficSourceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.traffic, size: 16, color: AppTheme.accentGreen),
                SizedBox(width: 6),
                Text('流量来源', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (!_hasTrafficData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '暂无流量来源数据',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              )
            else
              Column(
                children: [
                  _buildTrafficBar('推荐', _trafficRecommend, Colors.redAccent),
                  const SizedBox(height: 6),
                  _buildTrafficBar('搜索', _trafficSearch, Colors.blue),
                  const SizedBox(height: 6),
                  _buildTrafficBar('关注', _trafficFollow, Colors.green),
                  const SizedBox(height: 6),
                  _buildTrafficBar('同城', _trafficCity, Colors.orange),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficBar(String label, double value, Color color) {
    final total = _trafficRecommend + _trafficSearch + _trafficFollow + _trafficCity;
    final ratio = total > 0 ? value / total : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 36,
          child: Text(
            _pct(ratio),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ========== AI诊断卡 ==========
  Widget _buildDiagnosisCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('AI 频道诊断', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: _diagnosisLoading ? null : _runDiagnosis,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text(_diagnosisLoading ? '诊断中...' : '重新诊断', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_channelDiagnosisResult == null)
              _diagnosisLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Column(
                          children: [
                            Text('点击上方按钮开始AI诊断', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _runDiagnosis,
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('开始诊断'),
                            ),
                          ],
                        ),
                      ),
                    )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _channelDiagnosisResult!,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========== 发布时间分析 ==========
  Widget _buildPublishTimeAnalysisCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.schedule, size: 16, color: Colors.teal),
                SizedBox(width: 6),
                Text('最佳发布时间', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Spacer(),
                Icon(Icons.insights, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            _buildHourBars(),
            const SizedBox(height: 12),
            _buildWeekdayBars(),
            if (_hourPerformance.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildBestTimeTip(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHourBars() {
    if (_hourPerformance.isEmpty) {
      return Text('暂无数据', style: TextStyle(fontSize: 12, color: Colors.grey[500]));
    }

    final hours = List.generate(24, (i) => i);
    final maxPlays = _hourPerformance.values.isEmpty ? 1.0 : _hourPerformance.values.reduce(max);

    return SizedBox(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: hours.map((h) {
          final plays = _hourPerformance[h] ?? 0;
          final ratio = maxPlays > 0 ? plays / maxPlays : 0.0;
          final isTop = plays > 0 && plays >= maxPlays * 0.8;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isTop)
                    const Icon(Icons.arrow_drop_up, size: 10, color: Colors.red),
                  Container(
                    height: 20 + ratio * 25,
                    decoration: BoxDecoration(
                      color: isTop ? Colors.redAccent : Colors.teal.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    h.toString(),
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeekdayBars() {
    if (_weekdayPerformance.isEmpty) return const SizedBox.shrink();

    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final maxPlays = _weekdayPerformance.values.reduce(max);

    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final day = i + 1;
          final plays = _weekdayPerformance[day] ?? 0;
          final ratio = maxPlays > 0 ? plays / maxPlays : 0.0;
          final isTop = plays > 0 && plays >= maxPlays * 0.9;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 15 + ratio * 15,
                    decoration: BoxDecoration(
                      color: isTop ? Colors.amber : Colors.blue.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    weekdays[i],
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBestTimeTip() {
    final topHour = _hourPerformance.entries.reduce((a, b) => a.value > b.value ? a : b);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, size: 14, color: Colors.amber),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '建议在 ${topHour.key}:00 前后发布，平均播放量最高 (${_formatK(topHour.value)})',
              style: const TextStyle(fontSize: 11, color: Colors.brown),
            ),
          ),
        ],
      ),
    );
  }

  // ========== 热门视频卡 ==========
  Widget _buildTopVideosCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, size: 16, color: Colors.red),
                SizedBox(width: 6),
                Text('播放量TOP5', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ..._topVideos.asMap().entries.map((e) =>
              _buildVideoRankItem(e.key + 1, e.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoRankItem(int rank, Map<String, dynamic> video) {
    final title = video['title'] ?? '未知标题';
    final plays = (video['play_count'] as int?) ?? 0;
    final finish = (video['finish_rate'] as double?) ?? 0.0;

    final score = _calcVideoScore(video);
    final grade = VideoQualityAnalyzer.getQualityGrade(score);
    final gradeColor = Color(VideoQualityAnalyzer.getGradeColor(grade));

    return InkWell(
      onTap: () => context.go('/video/${video['id']}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: rank <= 3 ? Colors.red : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: rank <= 3 ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _formatK(plays.toDouble()),
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '完播${_pct(finish)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: gradeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                score.toStringAsFixed(0),
                style: TextStyle(fontSize: 10, color: gradeColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== 待优化视频卡 ==========
  Widget _buildLowQualityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, size: 16, color: Colors.orange),
                SizedBox(width: 6),
                Text('待优化视频', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            if (_lowQualityVideos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('暂无数据', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              )
            else
              ..._lowQualityVideos.map((v) => _buildLowQualityItem(v)),
          ],
        ),
      ),
    );
  }

  Widget _buildLowQualityItem(Map<String, dynamic> video) {
    final title = video['title'] ?? '未知标题';
    final plays = (video['play_count'] as int?) ?? 0;

    final analysis = VideoQualityAnalyzer.analyzeStrengthsWeaknesses(
      playCount: plays,
      likeCount: (video['like_count'] as int?) ?? 0,
      commentCount: (video['comment_count'] as int?) ?? 0,
      shareCount: (video['share_count'] as int?) ?? 0,
      collectCount: (video['collect_count'] as int?) ?? 0,
      finishRate: (video['finish_rate'] as double?) ?? 0.0,
      avgWatchDuration: (video['avg_watch_duration'] as double?) ?? 0.0,
      fiveSecondFinishRate: (video['five_second_finish_rate'] as double?) ?? 0.0,
      twoSecondExitRate: (video['two_second_exit_rate'] as double?) ?? 0.0,
      coverCtr: (video['cover_ctr'] as double?) ?? 0.0,
      newFollowers: (video['new_followers'] as int?) ?? 0,
      duration: (video['duration'] as double?) ?? 0.0,
    );

    final weaknesses = List<String>.from(analysis['weaknesses'] ?? []);
    final topIssue = weaknesses.isNotEmpty ? weaknesses.first : '需要优化';

    return InkWell(
      onTap: () => context.go('/video/${video['id']}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.arrow_downward, size: 12, color: Colors.orange),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatK(plays.toDouble())} · $topIssue',
                    style: TextStyle(fontSize: 10, color: Colors.orange[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatK(double num) {
    if (num >= 100000000) return '${(num / 100000000).toStringAsFixed(1)}亿';
    if (num >= 10000) return '${(num / 10000).toStringAsFixed(1)}万';
    return num.toStringAsFixed(0);
  }

  String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';
}
