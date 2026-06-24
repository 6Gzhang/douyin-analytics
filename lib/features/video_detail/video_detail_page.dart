import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format_utils.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../services/ai_service.dart';
import '../../utils/video_quality_analyzer.dart';

class VideoDetailPage extends ConsumerStatefulWidget {
  final String videoId;
  const VideoDetailPage({super.key, required this.videoId});

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends ConsumerState<VideoDetailPage>
    with SingleTickerProviderStateMixin {
  final _db = AppDatabase();
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  Map<String, dynamic>? _video;
  Map<String, dynamic>? _metrics;

  String _percentile = '--';
  bool _aiAnalyzing = false;
  bool _aiCommentsLoading = false;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final video = await _db.getVideoById(widget.videoId);
      final metrics = await _db.getMetricsForVideo(widget.videoId);

      int myPlays = (metrics?['play_count'] as int?) ?? 0;
      final allVideos = await _db.getAllVideos();
      final allPlays = <int>[];
      for (final v in allVideos) {
        final m = await _db.getMetricsForVideo(v['id'] as String);
        if (m != null) allPlays.add((m['play_count'] as int?) ?? 0);
      }
      allPlays.sort();
      int better = 0;
      for (final p in allPlays) {
        if (p < myPlays) better++;
      }
      String percentile = '--';
      if (allPlays.isNotEmpty) {
        final pct = (better / allPlays.length * 100).round();
        percentile = '超过 $pct% 的视频';
      }

      if (!mounted) return;
      setState(() {
        _video = video;
        _metrics = metrics;
        _percentile = percentile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '--';
    final dt = ts is int
        ? DateTime.fromMillisecondsSinceEpoch(ts * (ts > 1e12 ? 1 : 1000))
        : DateTime.tryParse(ts.toString()) ?? DateTime.now();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频详情'),
        bottom: _loading || _error != null || _video == null
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '数据概览'),
                  Tab(text: '互动分析'),
                  Tab(text: '优化建议'),
                ],
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('加载失败: $_error'));
    }
    if (_video == null) {
      return Center(
          child:
              Text('视频未找到', style: TextStyle(color: Colors.grey[500])));
    }

    final playCount = (_metrics?['play_count'] as int?) ?? 0;
    final likeCount = (_metrics?['like_count'] as int?) ?? 0;
    final commentCount = (_metrics?['comment_count'] as int?) ?? 0;
    final shareCount = (_metrics?['share_count'] as int?) ?? 0;
    final collectCount = (_metrics?['collect_count'] as int?) ?? 0;
    final finishRate = (_metrics?['finish_rate'] as double?) ?? 0.0;
    final avgWatch = (_metrics?['avg_watch_duration'] as double?) ?? 0.0;
    final twoSecExitRate = (_metrics?['two_second_exit_rate'] as double?) ?? 0.0;
    final coverCtr = (_metrics?['cover_ctr'] as double?) ?? 0.0;
    final title = _video!['title'] as String? ?? '无标题';
    final createTime = _video!['create_time'] as int?;
    final dateStr = createTime != null && createTime > 0
        ? DateTime.fromMillisecondsSinceEpoch(createTime * 1000)
            .toString()
            .substring(0, 16)
        : '--';

    return Column(
      children: [
        _buildHeader(title, dateStr, playCount, likeCount, commentCount,
            shareCount, collectCount, finishRate, avgWatch, twoSecExitRate, coverCtr),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(playCount, likeCount, commentCount, shareCount,
                  collectCount, finishRate, avgWatch, twoSecExitRate, coverCtr),
              _buildEngagementTab(playCount, likeCount, commentCount, shareCount, finishRate),
              _buildSuggestionsTab(finishRate, shareCount, commentCount, playCount, likeCount, title, {
                'play_count': playCount,
                'like_count': likeCount,
                'comment_count': commentCount,
                'share_count': shareCount,
                'collect_count': collectCount,
                'finish_rate': finishRate,
                'avg_watch_duration': avgWatch,
                'two_second_exit_rate': twoSecExitRate,
                'cover_ctr': coverCtr,
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(int playCount, int likeCount, int commentCount,
      int shareCount, int collectCount, double finishRate, double avgWatch,
      double twoSecExitRate, double coverCtr) {
    final duration = (_video?['duration'] as double?) ?? 0.0;
    final newFollowers = (_metrics?['new_followers'] as int?) ?? 0;
    final fiveSecFinish = (_metrics?['five_second_finish_rate'] as double?) ?? 0.0;

    final analysis = playCount > 0
        ? VideoQualityAnalyzer.analyzeStrengthsWeaknesses(
            playCount: playCount,
            likeCount: likeCount,
            commentCount: commentCount,
            shareCount: shareCount,
            collectCount: collectCount,
            finishRate: finishRate,
            avgWatchDuration: avgWatch,
            fiveSecondFinishRate: fiveSecFinish,
            twoSecondExitRate: twoSecExitRate,
            coverCtr: coverCtr,
            newFollowers: newFollowers,
            duration: duration,
          )
        : {'strengths': <String>[], 'weaknesses': <String>[]};

    final strengths = List<String>.from(analysis['strengths'] ?? []);
    final weaknesses = List<String>.from(analysis['weaknesses'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMetricsGrid(playCount, likeCount, commentCount, shareCount,
            collectCount, finishRate, avgWatch, twoSecExitRate, coverCtr),
        const SizedBox(height: 16),
        if (strengths.isNotEmpty || weaknesses.isNotEmpty)
          _buildStrengthsWeaknessesCard(strengths, weaknesses),
        const SizedBox(height: 16),
        _buildAdvancedDataNote(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStrengthsWeaknessesCard(List<String> strengths, List<String> weaknesses) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.thumb_up, size: 16, color: Colors.green),
                      SizedBox(width: 6),
                      Text('优势', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (strengths.isEmpty)
                    Text('暂无明显优势', style: TextStyle(fontSize: 12, color: Colors.grey[500]))
                  else
                    ...strengths.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle, size: 12, color: Colors.green),
                          const SizedBox(width: 6),
                          Expanded(child: Text(s, style: const TextStyle(fontSize: 12, height: 1.3))),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.arrow_downward, size: 16, color: Colors.orange),
                      SizedBox(width: 6),
                      Text('待提升', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (weaknesses.isEmpty)
                    Text('表现不错，继续保持', style: TextStyle(fontSize: 12, color: Colors.grey[500]))
                  else
                    ...weaknesses.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning, size: 12, color: Colors.orange),
                          const SizedBox(width: 6),
                          Expanded(child: Text(w, style: const TextStyle(fontSize: 12, height: 1.3))),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementTab(int plays, int likes, int comments, int shares,
      double finishRate) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFunnel(plays, likes, comments, shares),
        const SizedBox(height: 16),
        _buildRating(plays, likes, comments, shares, finishRate),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSuggestionsTab(double finishRate, int shareCount, int commentCount,
      int playCount, int likeCount, String title, Map<String, dynamic> metrics) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSuggestions(finishRate, shareCount, commentCount, playCount, likeCount),
        const SizedBox(height: 16),
        _buildAiButtons(title, metrics),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeader(String title, String date, int playCount, int likeCount,
      int commentCount, int shareCount, int collectCount, double finishRate,
      double avgWatch, double twoSecExit, double coverCtr) {
    // 计算质量评分
    final duration = (_video?['duration'] as double?) ?? 0.0;
    final newFollowers = (_metrics?['new_followers'] as int?) ?? 0;
    final fiveSecFinish = (_metrics?['five_second_finish_rate'] as double?) ?? 0.0;

    final qualityScore = playCount > 0
        ? VideoQualityAnalyzer.calculateQualityScore(
            playCount: playCount,
            likeCount: likeCount,
            commentCount: commentCount,
            shareCount: shareCount,
            collectCount: collectCount,
            finishRate: finishRate,
            avgWatchDuration: avgWatch,
            fiveSecondFinishRate: fiveSecFinish,
            twoSecondExitRate: twoSecExit,
            coverCtr: coverCtr,
            newFollowers: newFollowers,
            duration: duration,
          )
        : 0.0;

    final grade = VideoQualityAnalyzer.getQualityGrade(qualityScore);
    final gradeColor = Color(VideoQualityAnalyzer.getGradeColor(grade));
    final gradeText = VideoQualityAnalyzer.getGradeText(grade);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 106,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.play_circle_outline,
                      size: 36, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text('发布: ${_formatDate(_video?['create_time'])}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: gradeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  qualityScore.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: gradeColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '分',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: gradeColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: gradeColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    gradeText,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _percentile,
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(int playCount, int likeCount, int commentCount,
      int shareCount, int collectCount, double finishRate, double avgWatch,
      double twoSecExitRate, double coverCtr) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      children: [
        _tinyMetric('播放量', formatCount(playCount), Icons.play_circle,
            AppTheme.douyinRed),
        _tinyMetric(
            '点赞', formatCount(likeCount), Icons.favorite, AppTheme.douyinRed),
        _tinyMetric('评论', formatCount(commentCount), Icons.chat_bubble,
            AppTheme.accentBlue),
        _tinyMetric(
            '分享', formatCount(shareCount), Icons.share, AppTheme.douyinCyan),
        _tinyMetric('收藏', formatCount(collectCount), Icons.bookmark,
            AppTheme.accentAmber),
        _tinyMetric('完播率', '${finishRate.toStringAsFixed(1)}%', Icons.speed,
            AppTheme.accentGreen),
        _tinyMetric('均观时长', '${avgWatch.toStringAsFixed(1)}s', Icons.timer,
            AppTheme.accentPurple),
        _tinyMetric('2s跳出率', '${twoSecExitRate.toStringAsFixed(1)}%',
            Icons.exit_to_app, AppTheme.douyinRed),
        _tinyMetric('封面点击率', '${coverCtr.toStringAsFixed(1)}%',
            Icons.touch_app, AppTheme.accentGreen),
      ],
    );
  }

  Widget _tinyMetric(
      String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  // ---- 互动漏斗 (影视飓风风格) ----
  Widget _buildFunnel(
      int plays, int likes, int comments, int shares) {
    final likeRate = plays > 0 ? (likes / plays * 100) : 0.0;
    final commentRate = plays > 0 ? (comments / plays * 100) : 0.0;
    final shareRate = plays > 0 ? (shares / plays * 100) : 0.0;

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
                    color: AppTheme.accentBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('互动漏斗',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            _funnelRow(
                '播放量',
                formatCount(plays),
                plays,
                plays,
                AppTheme.douyinRed,
                '100%',
                true),
            const SizedBox(height: 10),
            _funnelRow('点赞率', formatCount(likes), likes, plays,
                AppTheme.douyinRed, '${likeRate.toStringAsFixed(2)}%'),
            const SizedBox(height: 10),
            _funnelRow('评论率', formatCount(comments), comments, plays,
                AppTheme.accentPurple, '${commentRate.toStringAsFixed(2)}%'),
            const SizedBox(height: 10),
            _funnelRow('分享率', formatCount(shares), shares, plays,
                AppTheme.douyinCyan, '${shareRate.toStringAsFixed(2)}%'),
          ],
        ),
      ),
    );
  }

  Widget _funnelRow(String label, String count, int numerator, int denominator,
      Color color, String pct,
      [bool isHead = false]) {
    final ratio = denominator > 0 ? (numerator / denominator) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: isHead ? FontWeight.w600 : FontWeight.normal)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.01, 1.0),
              minHeight: isHead ? 22 : 16,
              backgroundColor: color.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            '$count ($pct)',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  // ---- 表现评级 ----
  Widget _buildRating(int plays, int likes, int comments, int shares,
      double finishRate) {
    final interactionRate =
        plays > 0 ? ((likes + comments + shares) / plays * 100) : 0.0;
    String irLevel, frLevel;
    Color irColor, frColor;

    if (interactionRate >= 5) {
      irLevel = '高';
      irColor = AppTheme.accentGreen;
    } else if (interactionRate >= 2) {
      irLevel = '中';
      irColor = AppTheme.accentAmber;
    } else {
      irLevel = '低';
      irColor = AppTheme.douyinRed;
    }

    if (finishRate >= 40) {
      frLevel = '高';
      frColor = AppTheme.accentGreen;
    } else if (finishRate >= 20) {
      frLevel = '中';
      frColor = AppTheme.accentAmber;
    } else {
      frLevel = '低';
      frColor = AppTheme.douyinRed;
    }

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
                const Text('表现评级',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),
            _ratingRow('播放量百分位', _percentile, Icons.leaderboard,
                AppTheme.accentBlue),
            const Divider(height: 20),
            _ratingRow('互动率', '$irLevel (${interactionRate.toStringAsFixed(1)}%)',
                Icons.thumb_up, irColor),
            const Divider(height: 20),
            _ratingRow('完播率', '$frLevel (${finishRate.toStringAsFixed(1)}%)',
                Icons.speed, frColor),
          ],
        ),
      ),
    );
  }

  Widget _ratingRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ),
      ],
    );
  }

  // ---- 优化建议 ----
  Widget _buildSuggestions(double finishRate, int shareCount, int commentCount,
      int playCount, int likeCount) {
    final suggestions = <String>[];
    if (finishRate > 0 && finishRate < 20) {
      suggestions.add('完播率偏低：开头 3 秒可加强悬念或冲突，前 5 秒明确告诉观众"你能得到什么"');
    }
    if (playCount > 0 && shareCount > 0 && (shareCount / playCount * 100) < 0.5) {
      suggestions.add('分享率较低：结尾可增加引导分享的话术，如"转发给需要的人"');
    }
    if (playCount > 0 && commentCount > 0 && (commentCount / playCount * 100) < 0.5) {
      suggestions.add('评论互动偏低：可在视频中设置争议点或提问，引导观众在评论区讨论');
    }
    if (suggestions.isEmpty) {
      suggestions.add('各项指标表现均衡，继续保持内容质量，尝试拓展选题广度');
    }

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
                    color: AppTheme.accentGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('优化建议',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...suggestions.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(entry.value,
                          style: const TextStyle(
                              fontSize: 13, height: 1.5)),
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

  // ---- AI 按钮区 ----
  Widget _buildAiButtons(String title, Map<String, dynamic> metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                color: AppTheme.accentPurple,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text('AI 深度分析',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _aiAnalyzing ? null : () => _runAiAnalysisSheet(title, metrics),
                icon: _aiAnalyzing
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_aiAnalyzing ? '分析中...' : 'AI 深度分析'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _aiCommentsLoading ? null : _runMockCommentsSheet,
                icon: _aiCommentsLoading
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chat_bubble_outline, size: 16),
                label: Text(_aiCommentsLoading ? '生成中...' : '模拟观众反馈'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _runAiAnalysisSheet(String title, Map<String, dynamic> metrics) async {
    setState(() => _aiAnalyzing = true);
    try {
      final result = await AiService.instance.analyzeVideo(title, metrics);
      if (!mounted) return;
      setState(() => _aiAnalyzing = false);
      _showResultBottomSheet(context, 'AI 深度分析', result, AppTheme.accentPurple);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiAnalyzing = false);
      _showResultBottomSheet(context, 'AI 深度分析', '分析失败: $e', AppTheme.douyinRed);
    }
  }

  Future<void> _runMockCommentsSheet() async {
    setState(() => _aiCommentsLoading = true);
    try {
      final result = await AiService.instance.chat(
        '你是抖音观众，请对这条视频生成3条不同立场的评论：1条正面、1条中性、1条负面。每条30字左右，用[正面]/[中性]/[负面]标记。不要额外解释。',
        '视频标题：${_video?['title'] ?? ""}\n播放量：${_metrics?['play_count'] ?? 0}\n点赞：${_metrics?['like_count'] ?? 0}\n评论：${_metrics?['comment_count'] ?? 0}',
      );
      if (!mounted) return;
      setState(() => _aiCommentsLoading = false);
      _showResultBottomSheet(context, '模拟观众反馈', result, AppTheme.accentGreen);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiCommentsLoading = false);
      _showResultBottomSheet(context, '模拟观众反馈', '生成失败: $e', AppTheme.douyinRed);
    }
  }

  void _showResultBottomSheet(BuildContext context, String title, String content, Color accentColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (ctx2, scrollController) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 4, height: 20,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(content,
                          style: const TextStyle(fontSize: 14, height: 1.7)),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAdvancedDataNote() {
    return Card(
      color: AppTheme.accentAmber.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                color: AppTheme.accentAmber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('高阶数据',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    '逐秒互动热力图需在抖音创作者后台「视频数据 → 观看分析」中查看。当前仅支持视频级统计数据。',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
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
