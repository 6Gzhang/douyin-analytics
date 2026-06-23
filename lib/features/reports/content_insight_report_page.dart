import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format_utils.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';

class ContentInsightReportPage extends ConsumerStatefulWidget {
  const ContentInsightReportPage({super.key});

  @override
  ConsumerState<ContentInsightReportPage> createState() =>
      _ContentInsightReportPageState();
}

class _ContentInsightReportPageState
    extends ConsumerState<ContentInsightReportPage> {
  final _db = AppDatabase();
  bool _loading = true;
  List<Map<String, dynamic>> _topPlays = [];
  List<Map<String, dynamic>> _topLikes = [];
  List<Map<String, dynamic>> _lowPlays = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final videos = await _db.getAllVideos();
      final enriched = <Map<String, dynamic>>[];
      for (final v in videos) {
        final metrics = await _db.getMetricsForVideo(v['id'] as String);
        final combined = Map<String, dynamic>.from(v);
        if (metrics != null) combined.addAll(metrics);
        enriched.add(combined);
      }

      enriched.sort(
          (a, b) => ((b['play_count'] ?? 0) as int).compareTo((a['play_count'] ?? 0) as int));
      final topPlays = enriched.take(5).toList();
      final lowPlays = enriched.length <= 5
          ? <Map<String, dynamic>>[]
          : enriched.sublist(enriched.length - 3).reversed.toList();

      enriched.sort(
          (a, b) => ((b['like_count'] ?? 0) as int).compareTo((a['like_count'] ?? 0) as int));
      final topLikes = enriched.take(5).toList();

      if (!mounted) return;
      setState(() {
        _topPlays = topPlays;
        _topLikes = topLikes;
        _lowPlays = lowPlays;
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
      appBar: AppBar(title: const Text('内容洞察报告')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_topPlays.isEmpty) {
      return Center(
          child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection('Top 5 高播放视频', _topPlays, AppTheme.douyinRed),
        const SizedBox(height: 16),
        _buildSection('Top 5 高互动视频', _topLikes, AppTheme.douyinCyan),
        if (_lowPlays.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSection('需要优化的视频', _lowPlays, Colors.orange),
        ],
      ],
    );
  }

  Widget _buildSection(
      String title, List<Map<String, dynamic>> videos, Color accent) {
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
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...videos.map((v) {
              final playCount = (v['play_count'] as int?) ?? 0;
              final likeCount = (v['like_count'] as int?) ?? 0;
              final titleText = v['title'] as String? ?? '无标题';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () =>
                      context.push('/video/${v['id']}'),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(titleText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text(
                                '播放 ${formatCount(playCount)}  |  点赞 ${formatCount(likeCount)}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
