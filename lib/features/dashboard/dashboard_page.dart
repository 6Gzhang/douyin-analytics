import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format_utils.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../services/ai_service.dart';
import '../../widgets/trend_chart.dart';
import '../../widgets/ai_insight_card.dart';

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
  double _avgFinishRate = 0.0;
  double _avgWatchDuration = 0.0;
  List<Map<String, dynamic>> _recentVideos = [];
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
      double totalFR = 0, totalAW = 0;
      int frCount = 0, awCount = 0;

      for (final v in videos) {
        plays += (v['play_count'] as int?) ?? 0;
        likes += (v['like_count'] as int?) ?? 0;
        comments += (v['comment_count'] as int?) ?? 0;
        shares += (v['share_count'] as int?) ?? 0;
        collects += (v['collect_count'] as int?) ?? 0;
        final fr = (v['finish_rate'] as double?) ?? 0.0;
        final aw = (v['avg_watch_duration'] as double?) ?? 0.0;
        if (fr > 0) {
          totalFR += fr;
          frCount++;
        }
        if (aw > 0) {
          totalAW += aw;
          awCount++;
        }
      }

      final recentVideos = videos.toList();
      recentVideos.sort(
          (a, b) => (b['create_time'] as int).compareTo(a['create_time'] as int));
      final recent5 = recentVideos.take(5).toList();

      if (!mounted) return;
      setState(() {
        _totalVideos = videos.length;
        _totalPlays = plays;
        _totalLikes = likes;
        _totalComments = comments;
        _totalShares = shares;
        _totalCollects = collects;
        _avgFinishRate = frCount > 0 ? totalFR / frCount : 0.0;
        _avgWatchDuration = awCount > 0 ? totalAW / awCount : 0.0;
        _recentVideos = recent5;
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
        title: const Text('概览'),
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
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryGrid(),
          const SizedBox(height: 16),
          _buildChannelDiagnosisCard(),
          const SizedBox(height: 16),
          _buildRecentVideos(),
          if (_recentVideos.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTrendChart(),
            const SizedBox(height: 16),
            const AiInsightCard(),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _runChannelDiagnosis() async {
    setState(() => _diagnosisLoading = true);
    try {
      final stats = await _db.getChannelStats();
      final result = await AiService.instance.channelDiagnosis(stats);
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

  Widget _buildChannelDiagnosisCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                const Expanded(
                  child: Text('AI 频道诊断',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                if (_diagnosisLoading)
                  const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                const Icon(Icons.auto_awesome, size: 16, color: AppTheme.accentPurple),
              ],
            ),
            if (_channelDiagnosisResult != null) ...[
              const SizedBox(height: 12),
              Text(_channelDiagnosisResult!,
                  style: const TextStyle(fontSize: 13, height: 1.5)),
            ] else ...[
              const SizedBox(height: 12),
              Text('一键分析频道整体表现，找出优势和问题',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _runChannelDiagnosis,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('开始诊断'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return Column(
      children: [
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return _coreMetric('总播放', formatCount(_totalPlays),
                      Icons.play_circle, AppTheme.douyinRed);
                case 1:
                  return _coreMetric('总点赞', formatCount(_totalLikes),
                      Icons.favorite, AppTheme.douyinRed);
                case 2:
                  return _coreMetric('总评论', formatCount(_totalComments),
                      Icons.chat_bubble, AppTheme.accentBlue);
                case 3:
                  return _coreMetric('总分享', formatCount(_totalShares),
                      Icons.share, AppTheme.douyinCyan);
                default:
                  return const SizedBox.shrink();
              }
            },
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                    child: _compactMetric(
                        '收藏', formatCount(_totalCollects), Icons.bookmark, AppTheme.accentAmber)),
                Expanded(
                    child: _compactMetric('完播率', '${_avgFinishRate.toStringAsFixed(1)}%',
                        Icons.speed, AppTheme.accentGreen)),
                Expanded(
                    child: _compactMetric('视频数', '$_totalVideos',
                        Icons.video_library, AppTheme.accentPurple)),
                Expanded(
                    child: _compactMetric('观时长', '${_avgWatchDuration.toStringAsFixed(1)}s',
                        Icons.timer, const Color(0xFF6366F1))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _coreMetric(String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _compactMetric(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildRecentVideos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('最近视频',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => context.go('/videos'),
                  child: const Text('查看全部',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._recentVideos.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push('/video/${v['id']}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black)
                            .withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              v['title'] as String? ?? '无标题',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 16, color: Colors.grey[400]),
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

  Widget _buildTrendChart() {
    return const TrendChart(key: ValueKey('dashboard_trend'));
  }
}
