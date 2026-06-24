import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data_sources/feishu_service.dart';
import '../../core/format_utils.dart';
import '../../data/database/database.dart';

class FeishuDataPage extends ConsumerStatefulWidget {
  const FeishuDataPage({super.key});

  @override
  ConsumerState<FeishuDataPage> createState() => _FeishuDataPageState();
}

class _FeishuDataPageState extends ConsumerState<FeishuDataPage> {
  final FeishuService _feishuService = FeishuService(AppDatabase());
  List<FeishuDouyinMetric> _metrics = [];
  bool _loading = false;
  String? _error;
  bool _notConfigured = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _notConfigured = false;
    });

    try {
      final isConfigured = await _feishuService.isConfigured();
      if (!isConfigured) {
        setState(() {
          _loading = false;
          _notConfigured = true;
        });
        return;
      }

      final records = await _feishuService.fetchRecords();
      final metrics = FeishuService.parseDouyinMetrics(records);

      if (!mounted) return;
      setState(() {
        _metrics = metrics;
        _loading = false;
      });
    } on FeishuException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '数据拉取失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('飞书数据'),
        actions: [
          if (!_notConfigured)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _loadData,
              tooltip: '刷新数据',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notConfigured) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.table_chart_outlined,
                  size: 72, color: Colors.grey[350]),
              const SizedBox(height: 20),
              Text(
                '飞书数据源未配置',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                '影刀 RPA / n8n → 飞书多维表格 → 本 APP',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.settings),
                label: const Text('去配置'),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/settings'),
                    icon: const Icon(Icons.settings),
                    label: const Text('检查配置'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_metrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_chart_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('暂无数据',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(
              '多维表格中无记录，或列名不匹配',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    final totalPlays = _metrics.fold<int>(0, (s, m) => s + m.playCount);
    final totalLikes = _metrics.fold<int>(0, (s, m) => s + m.likeCount);
    final totalComments = _metrics.fold<int>(0, (s, m) => s + m.commentCount);
    final totalShares = _metrics.fold<int>(0, (s, m) => s + m.shareCount);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _buildSummaryCard('总播放', formatCount(totalPlays),
                  Icons.play_arrow, const Color(0xFF2196F3)),
              const SizedBox(width: 8),
              _buildSummaryCard('总点赞', formatCount(totalLikes),
                  Icons.favorite, const Color(0xFFFE2C55)),
              const SizedBox(width: 8),
              _buildSummaryCard('总评论', formatCount(totalComments),
                  Icons.chat_bubble, const Color(0xFFFF9800)),
              const SizedBox(width: 8),
              _buildSummaryCard('总分享', formatCount(totalShares),
                  Icons.share, const Color(0xFF4CAF50)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('视频记录 (${_metrics.length})',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 16),
                label:
                    const Text('刷新', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._metrics.asMap().entries.map((entry) {
            final idx = entry.key;
            final m = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFE2C55)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${idx + 1}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFE2C55))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            m.videoTitle.isNotEmpty
                                ? m.videoTitle
                                : '视频 #${idx + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (m.publishDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 38),
                        child: Text(m.publishDate,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400])),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 38),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 6,
                        children: [
                          _buildStat('播放', m.playCount, Icons.play_arrow,
                              const Color(0xFF2196F3)),
                          _buildStat('点赞', m.likeCount, Icons.favorite,
                              const Color(0xFFFE2C55)),
                          _buildStat('评论', m.commentCount,
                              Icons.chat_bubble, const Color(0xFFFF9800)),
                          _buildStat('分享', m.shareCount, Icons.share,
                              const Color(0xFF4CAF50)),
                          if (m.finishRate != null)
                            _buildStat(
                                '完播率',
                                null,
                                Icons.timelapse,
                                const Color(0xFF9C27B0),
                                suffix:
                                    '${m.finishRate!.toStringAsFixed(1)}%'),
                          if (m.avgWatchDuration != null)
                            _buildStat(
                                '均观时',
                                null,
                                Icons.timer,
                                const Color(0xFF607D8B),
                                suffix:
                                    '${m.avgWatchDuration!.toStringAsFixed(1)}s'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.07),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.15)),
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(
      String label, dynamic value, IconData icon, Color color,
      {String? suffix}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          '$label ${suffix ?? formatCount(value as int)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
