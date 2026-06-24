import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format_utils.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../services/ai_service.dart';
import '../../widgets/trend_chart.dart';

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

  int _totalVideos = 0;
  int _totalPlays = 0;
  int _totalLikes = 0;
  int _totalComments = 0;
  int _totalShares = 0;
  int _totalCollects = 0;
  int _totalProfileVisits = 0;
  double _avgFinishRate = 0.0;
  double _avgWatchDuration = 0.0;
  double _avgTwoSecExit = 0.0;
  double _avgCoverCtr = 0.0;
  double _likeRate = 0.0;
  double _commentRate = 0.0;
  double _shareRate = 0.0;
  double _collectRate = 0.0;
  double _avgPlays = 0.0;
  double _interactionRate = 0.0;

  List<Map<String, dynamic>> _recentVideos = [];
  List<Map<String, dynamic>> _top5Plays = [];
  List<Map<String, dynamic>> _top5Interaction = [];
  List<Map<String, dynamic>> _lowFinish = [];
  bool _hasData = false;

  String? _channelDiagnosisResult;
  bool _diagnosisLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await _db.getAllVideosWithMetrics();

      int plays = 0, likes = 0, comments = 0, shares = 0, collects = 0;
      int profileVisits = 0;
      double totalFR = 0, totalAW = 0, total2s = 0, totalCover = 0;
      int frCount = 0, awCount = 0, exit2sCount = 0, coverCount = 0;

      for (final v in videos) {
        plays += (v['play_count'] as int?) ?? 0;
        likes += (v['like_count'] as int?) ?? 0;
        comments += (v['comment_count'] as int?) ?? 0;
        shares += (v['share_count'] as int?) ?? 0;
        collects += (v['collect_count'] as int?) ?? 0;
        profileVisits += (v['profile_visits'] as int?) ?? 0;

        final fr = (v['finish_rate'] as double?) ?? 0.0;
        final aw = (v['avg_watch_duration'] as double?) ?? 0.0;
        final e2s = (v['two_second_exit_rate'] as double?) ?? 0.0;
        final ctr = (v['cover_ctr'] as double?) ?? 0.0;

        if (fr > 0) {totalFR += fr; frCount++;}
        if (aw > 0) {totalAW += aw; awCount++;}
        if (e2s > 0) {total2s += e2s; exit2sCount++;}
        if (ctr > 0) {totalCover += ctr; coverCount++;}
      }

      final sortedByTime = List<Map<String, dynamic>>.from(videos)
        ..sort((a, b) =>
            (b['create_time'] as int? ?? 0).compareTo(a['create_time'] as int? ?? 0));
      final recent5 = sortedByTime.take(5).toList();

      final sortedByPlays = List<Map<String, dynamic>>.from(videos)
        ..sort((a, b) =>
            ((b['play_count'] as int?) ?? 0).compareTo((a['play_count'] as int?) ?? 0));
      final top5Plays = sortedByPlays.take(5).toList();

      final sortedByInteraction = List<Map<String, dynamic>>.from(videos)
        ..sort((a, b) {
          final ap = ((a['like_count'] as int?) ?? 0) + ((a['comment_count'] as int?) ?? 0) + ((a['share_count'] as int?) ?? 0);
          final bp = ((b['like_count'] as int?) ?? 0) + ((b['comment_count'] as int?) ?? 0) + ((b['share_count'] as int?) ?? 0);
          return bp.compareTo(ap);
        });
      final top5Interaction = sortedByInteraction.take(5).toList();

      final lowFinish = videos.where((v) {
        final fr = (v['finish_rate'] as double?) ?? 0;
        return fr > 0 && fr < 30;
      }).toList()
        ..sort((a, b) =>
            ((a['finish_rate'] as double?) ?? 0).compareTo((b['finish_rate'] as double?) ?? 0));
      final lowFinishTop = lowFinish.take(5).toList();

      final avgPlaysVal = videos.isNotEmpty ? plays / videos.length : 0;
      final likeRateVal = plays > 0 ? likes / plays * 100 : 0;
      final commentRateVal = plays > 0 ? comments / plays * 100 : 0;
      final shareRateVal = plays > 0 ? shares / plays * 100 : 0;
      final collectRateVal = plays > 0 ? collects / plays * 100 : 0;
      final interactionVal = plays > 0 ? (likes + comments + shares) / plays * 100 : 0;

      if (!mounted) return;
      setState(() {
        _totalVideos = videos.length;
        _totalPlays = plays;
        _totalLikes = likes;
        _totalComments = comments;
        _totalShares = shares;
        _totalCollects = collects;
        _totalProfileVisits = profileVisits;
        _avgFinishRate = frCount > 0 ? totalFR / frCount : 0.0;
        _avgWatchDuration = awCount > 0 ? totalAW / awCount : 0.0;
        _avgTwoSecExit = exit2sCount > 0 ? total2s / exit2sCount : 0.0;
        _avgCoverCtr = coverCount > 0 ? totalCover / coverCount : 0.0;
        _avgPlays = avgPlaysVal;
        _likeRate = likeRateVal;
        _commentRate = commentRateVal;
        _shareRate = shareRateVal;
        _collectRate = collectRateVal;
        _interactionRate = interactionVal;
        _recentVideos = recent5;
        _top5Plays = top5Plays;
        _top5Interaction = top5Interaction;
        _lowFinish = lowFinishTop;
        _hasData = videos.isNotEmpty && plays > 0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据概览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI 分析助手',
            onPressed: () => context.push('/ai-assistant'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
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
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('加载失败', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(_error!,
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadDashboardData, child: const Text('重试')),
          ],
        ),
      );
    }

    if (!_hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无数据',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(
              '请通过设置页导入抖音 CSV 数据',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildCoreMetrics(),
          const SizedBox(height: 10),
          _buildRateMetrics(),
          const SizedBox(height: 10),
          _buildChannelDiagnosisCard(),
          const SizedBox(height: 10),
          _buildQuickInsights(),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTopList('播放TOP5', _top5Plays, AppTheme.douyinRed, 'play_count')),
              const SizedBox(width: 10),
              Expanded(child: _buildTopList('互动TOP5', _top5Interaction, AppTheme.douyinCyan, 'interaction')),
            ],
          ),
          if (_lowFinish.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildLowFinishWarning(),
          ],
          const SizedBox(height: 10),
          _buildRecentVideos(),
          const SizedBox(height: 10),
          const TrendChart(key: ValueKey('dashboard_trend')),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCoreMetrics() {
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          switch (index) {
            case 0: return _metricCard('总播放', formatCount(_totalPlays), Icons.play_circle_fill, AppTheme.douyinRed);
            case 1: return _metricCard('总点赞', formatCount(_totalLikes), Icons.favorite, AppTheme.douyinRed);
            case 2: return _metricCard('总评论', formatCount(_totalComments), Icons.chat_bubble, AppTheme.accentBlue);
            case 3: return _metricCard('总分享', formatCount(_totalShares), Icons.share, AppTheme.douyinCyan);
            case 4: return _metricCard('总收藏', formatCount(_totalCollects), Icons.bookmark, AppTheme.accentAmber);
            default: return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(title,
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildRateMetrics() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _smallMetric('均播放', formatCount(_avgPlays.round()), Icons.ondemand_video, AppTheme.accentPurple)),
                Expanded(child: _smallMetric('完播率', '${_avgFinishRate.toStringAsFixed(1)}%', Icons.speed, AppTheme.accentGreen)),
                Expanded(child: _smallMetric('观时长', '${_avgWatchDuration.toStringAsFixed(1)}s', Icons.timer, const Color(0xFF6366F1))),
                Expanded(child: _smallMetric('视频数', '$_totalVideos', Icons.video_library, Colors.grey[600]!)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _rateItem('点赞率', _likeRate, AppTheme.douyinRed)),
                Expanded(child: _rateItem('评论率', _commentRate, AppTheme.accentBlue)),
                Expanded(child: _rateItem('分享率', _shareRate, AppTheme.douyinCyan)),
                Expanded(child: _rateItem('收藏率', _collectRate, AppTheme.accentAmber)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallMetric(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _rateItem(String label, double rate, Color color) {
    return Column(
      children: [
        Text('${rate.toStringAsFixed(2)}%',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        const SizedBox(height: 4),
        SizedBox(
          width: 40,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (rate / 10).clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelDiagnosisCard() {
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
                    color: AppTheme.accentPurple,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('AI 频道诊断',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                if (_diagnosisLoading)
                  const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                const Icon(Icons.auto_awesome, size: 14, color: AppTheme.accentPurple),
              ],
            ),
            if (_channelDiagnosisResult != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_channelDiagnosisResult!,
                    style: const TextStyle(fontSize: 12, height: 1.6)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _diagnosisLoading ? null : _runChannelDiagnosis,
                  child: const Text('重新诊断', style: TextStyle(fontSize: 12)),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text('一键分析频道整体表现，找出优势、短板和增长建议',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _diagnosisLoading ? null : _runChannelDiagnosis,
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('开始诊断', style: TextStyle(fontSize: 12)),
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

  Future<void> _runChannelDiagnosis() async {
    setState(() => _diagnosisLoading = true);
    try {
      final stats = await _db.getChannelStats();
      final enhancedStats = Map<String, dynamic>.from(stats);
      enhancedStats['total_profile_visits'] = _totalProfileVisits;
      final result = await AiService.instance.channelDiagnosis(enhancedStats);
      if (!mounted) return;
      setState(() {
        _channelDiagnosisResult = result;
        _diagnosisLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _channelDiagnosisResult = '诊断失败: $e';
        _diagnosisLoading = false;
      });
    }
  }

  Widget _buildQuickInsights() {
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
                const Text('数据洞察',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _insightItem(_avgFinishRate > 40 ? Icons.check_circle : Icons.warning,
                    _avgFinishRate > 40 ? '完播率健康' : '完播率偏低',
                    '${_avgFinishRate.toStringAsFixed(1)}%',
                    _avgFinishRate > 40 ? AppTheme.accentGreen : AppTheme.douyinRed)),
                Expanded(child: _insightItem(_likeRate > 3 ? Icons.check_circle : Icons.info_outline,
                    _likeRate > 3 ? '点赞率优秀' : '点赞率待提升',
                    '${_likeRate.toStringAsFixed(2)}%',
                    _likeRate > 3 ? AppTheme.accentGreen : AppTheme.accentAmber)),
                Expanded(child: _insightItem(_commentRate > 0.3 ? Icons.check_circle : Icons.info_outline,
                    _commentRate > 0.3 ? '评论活跃' : '评论偏少',
                    '${_commentRate.toStringAsFixed(2)}%',
                    _commentRate > 0.3 ? AppTheme.accentGreen : AppTheme.accentBlue)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _insightItem(IconData icon, String title, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopList(String title, List<Map<String, dynamic>> items, Color accent, String sortKey) {
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
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.asMap().entries.map((entry) {
              final idx = entry.key;
              final v = entry.value;
              final val = sortKey == 'interaction'
                  ? ((v['like_count'] as int?) ?? 0) + ((v['comment_count'] as int?) ?? 0) + ((v['share_count'] as int?) ?? 0)
                  : (v[sortKey] as int?) ?? 0;
              return InkWell(
                onTap: () => context.push('/video/${v['id']}'),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: idx < 3 ? accent.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text('${idx + 1}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                color: idx < 3 ? accent : Colors.grey[600])),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(v['title'] as String? ?? '无标题',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      Text(formatCount(val),
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w600, color: accent)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLowFinishWarning() {
    return Card(
      margin: EdgeInsets.zero,
      color: AppTheme.douyinRed.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, size: 16, color: AppTheme.douyinRed),
                const SizedBox(width: 6),
                const Text('完播率预警',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.douyinRed)),
              ],
            ),
            const SizedBox(height: 6),
            Text('${_lowFinish.length}条视频完播率低于30%，建议优先优化',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 8),
            ..._lowFinish.take(3).map((v) {
              final fr = (v['finish_rate'] as double?) ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(v['title'] as String? ?? '无标题',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    Text('${fr.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.douyinRed)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentVideos() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3, height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('最近视频',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/videos'),
                  child: const Text('查看全部', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            ..._recentVideos.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => context.push('/video/${v['id']}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              v['title'] as String? ?? '无标题',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(formatCount(v['play_count'] as int? ?? 0),
                              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          Icon(Icons.chevron_right, size: 14, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
