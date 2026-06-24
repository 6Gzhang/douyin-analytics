import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format_utils.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../services/ai_service.dart';

class ContentInsightReportPage extends ConsumerStatefulWidget {
  const ContentInsightReportPage({super.key});

  @override
  ConsumerState<ContentInsightReportPage> createState() =>
      _ContentInsightReportPageState();
}

class _ContentInsightReportPageState
    extends ConsumerState<ContentInsightReportPage> with SingleTickerProviderStateMixin {
  final _db = AppDatabase();
  bool _loading = true;
  late TabController _tabController;

  List<Map<String, dynamic>> _allVideos = [];
  List<Map<String, dynamic>> _topPlays = [];
  List<Map<String, dynamic>> _topInteraction = [];
  List<Map<String, dynamic>> _topFinishRate = [];
  List<Map<String, dynamic>> _lowPlays = [];
  List<Map<String, dynamic>> _highExit = [];

  double _avgPlayCount = 0;
  double _avgInteractionRate = 0;
  double _avgFinishRate = 0;

  String? _aiAnalysis;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      _allVideos = videos;

      final sortedPlays = List<Map<String, dynamic>>.from(videos)
        ..sort((a, b) =>
            ((b['play_count'] ?? 0) as int).compareTo((a['play_count'] ?? 0) as int));
      final topPlays = sortedPlays.take(10).toList();
      final lowPlays = videos.length > 10
          ? sortedPlays.sublist((sortedPlays.length * 0.7).floor()).reversed.toList().take(5).toList()
          : <Map<String, dynamic>>[];

      final withInteraction = videos.map((v) {
        final p = (v['play_count'] as int?) ?? 0;
        final l = (v['like_count'] as int?) ?? 0;
        final c = (v['comment_count'] as int?) ?? 0;
        final s = (v['share_count'] as int?) ?? 0;
        final rate = p > 0 ? (l + c + s) / p * 100 : 0.0;
        final copy = Map<String, dynamic>.from(v);
        copy['interaction_rate'] = rate;
        return copy;
      }).toList();
      withInteraction.sort((a, b) =>
          (b['interaction_rate'] as double).compareTo(a['interaction_rate'] as double));
      final topInteraction = withInteraction.take(10).toList();

      final withFinish = videos.where((v) {
        final fr = (v['finish_rate'] as double?) ?? 0;
        return fr > 0;
      }).toList();
      withFinish.sort((a, b) =>
          ((b['finish_rate'] as double?) ?? 0).compareTo((a['finish_rate'] as double?) ?? 0));
      final topFinishRate = withFinish.take(10).toList();

      final highExit = videos.where((v) {
        final e = (v['two_second_exit_rate'] as double?) ?? 0;
        return e > 40;
      }).toList()
        ..sort((a, b) =>
            ((b['two_second_exit_rate'] as double?) ?? 0).compareTo((a['two_second_exit_rate'] as double?) ?? 0));

      int totalPlays = 0;
      double totalInteractionRate = 0;
      double totalFinishRate = 0;
      int finishCount = 0;

      for (final v in videos) {
        final p = (v['play_count'] as int?) ?? 0;
        final l = (v['like_count'] as int?) ?? 0;
        final c = (v['comment_count'] as int?) ?? 0;
        final s = (v['share_count'] as int?) ?? 0;
        final fr = (v['finish_rate'] as double?) ?? 0;
        totalPlays += p;
        if (p > 0) totalInteractionRate += (l + c + s) / p * 100;
        if (fr > 0) {totalFinishRate += fr; finishCount++;}
      }

      if (!mounted) return;
      setState(() {
        _topPlays = topPlays;
        _topInteraction = topInteraction;
        _topFinishRate = topFinishRate;
        _lowPlays = lowPlays;
        _highExit = highExit;
        _avgPlayCount = videos.isNotEmpty ? totalPlays / videos.length : 0;
        _avgInteractionRate = videos.isNotEmpty ? totalInteractionRate / videos.length : 0;
        _avgFinishRate = finishCount > 0 ? totalFinishRate / finishCount : 0;
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
        title: const Text('内容洞察'),
        bottom: _loading
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: '高播放'),
                  Tab(text: '高互动'),
                  Tab(text: '高完播'),
                  Tab(text: '待优化'),
                ],
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_allVideos.isEmpty) {
      return Center(
          child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])));
    }
    return Column(
      children: [
        _buildSummaryBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildVideoList(_topPlays, AppTheme.douyinRed, 'play_count'),
              _buildVideoList(_topInteraction, AppTheme.douyinCyan, 'interaction_rate'),
              _buildVideoList(_topFinishRate, AppTheme.accentGreen, 'finish_rate'),
              _buildLowQualityTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(child: _summaryItem('均播放', formatCount(_avgPlayCount.round()), Icons.ondemand_video, AppTheme.douyinRed)),
          Expanded(child: _summaryItem('互动率', '${_avgInteractionRate.toStringAsFixed(2)}%', Icons.favorite, AppTheme.douyinCyan)),
          Expanded(child: _summaryItem('完播率', '${_avgFinishRate.toStringAsFixed(1)}%', Icons.speed, AppTheme.accentGreen)),
          Expanded(child: _summaryItem('视频数', '${_allVideos.length}', Icons.video_library, AppTheme.accentPurple)),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildVideoList(List<Map<String, dynamic>> videos, Color accent, String sortKey) {
    if (videos.isEmpty) {
      return Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final v = videos[index];
        final title = v['title'] as String? ?? '无标题';
        final plays = (v['play_count'] as int?) ?? 0;
        final likes = (v['like_count'] as int?) ?? 0;
        final comments = (v['comment_count'] as int?) ?? 0;
        final shares = (v['share_count'] as int?) ?? 0;

        String displayValue;
        String displayLabel;
        if (sortKey == 'play_count') {
          displayValue = formatCount(plays);
          displayLabel = '播放';
        } else if (sortKey == 'interaction_rate') {
          final rate = v['interaction_rate'] as double? ?? 0;
          displayValue = '${rate.toStringAsFixed(2)}%';
          displayLabel = '互动率';
        } else {
          final fr = (v['finish_rate'] as double?) ?? 0;
          displayValue = '${fr.toStringAsFixed(1)}%';
          displayLabel = '完播率';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.push('/video/${v['id']}'),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: index < 3
                          ? accent.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: index < 3 ? accent : Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _miniStat('赞', likes, AppTheme.douyinRed),
                            const SizedBox(width: 8),
                            _miniStat('评', comments, AppTheme.accentBlue),
                            const SizedBox(width: 8),
                            _miniStat('转', shares, AppTheme.douyinCyan),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(displayValue,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accent)),
                      Text(displayLabel,
                          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatCount(value),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildLowQualityTab() {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        if (_lowPlays.isNotEmpty) ...[
          _buildSectionCard('低播放视频 TOP5', _lowPlays, Colors.orange, 'play_count'),
          const SizedBox(height: 10),
        ],
        if (_highExit.isNotEmpty) ...[
          _buildSectionCard('高跳出率视频（2秒跳出>40%）', _highExit, AppTheme.douyinRed, 'two_second_exit_rate'),
          const SizedBox(height: 10),
        ],
        _buildAiAnalysisCard(),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Map<String, dynamic>> videos, Color accent, String valueKey) {
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
                Text('${videos.length}条',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 8),
            ...videos.take(5).toList().asMap().entries.map((entry) {
              final v = entry.value;
              final titleText = v['title'] as String? ?? '无标题';
              String val;
              if (valueKey == 'two_second_exit_rate') {
                val = '${((v['two_second_exit_rate'] as double?) ?? 0).toStringAsFixed(1)}%';
              } else {
                val = formatCount((v[valueKey] as int?) ?? 0);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: InkWell(
                  onTap: () => context.push('/video/${v['id']}'),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(titleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Text(val,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent)),
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

  Widget _buildAiAnalysisCard() {
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
                  child: Text('AI 内容策略分析',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const Icon(Icons.auto_awesome, size: 14, color: AppTheme.accentPurple),
              ],
            ),
            const SizedBox(height: 8),
            if (_aiAnalysis != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_aiAnalysis!,
                    style: const TextStyle(fontSize: 12, height: 1.6)),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _aiLoading ? null : _runAiAnalysis,
                  child: const Text('重新分析', style: TextStyle(fontSize: 11)),
                ),
              ),
            ] else ...[
              Text('基于高播放和低播放视频对比，分析爆款基因和优化方向',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _aiLoading ? null : _runAiAnalysis,
                  icon: _aiLoading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('开始分析', style: TextStyle(fontSize: 12)),
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

  Future<void> _runAiAnalysis() async {
    setState(() => _aiLoading = true);
    try {
      final result = await AiService.instance.contentStrategyAnalysis(_allVideos);
      if (!mounted) return;
      setState(() {
        _aiAnalysis = result;
        _aiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiAnalysis = '分析失败: $e';
        _aiLoading = false;
      });
    }
  }
}
