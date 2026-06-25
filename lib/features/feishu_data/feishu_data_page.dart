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
  final AppDatabase _db = AppDatabase();
  List<FeishuDouyinMetric> _metrics = [];
  bool _loading = false;
  bool _importing = false;
  int _importedCount = 0;
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

  /// 自动导入飞书数据到本地数据库
  Future<void> _importToDatabase() async {
    if (_metrics.isEmpty) return;

    setState(() {
      _importing = true;
      _importedCount = 0;
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      int count = 0;

      for (final m in _metrics) {
        // 生成视频 ID（如果没有）
        final videoId = m.videoId.isNotEmpty 
            ? m.videoId 
            : 'feishu_${now}_${count}';

        // 插入视频基础信息
        await _db.upsertVideo(
          id: videoId,
          title: m.videoTitle.isNotEmpty ? m.videoTitle : '视频 #${count + 1}',
          createTime: _parseDate(m.publishDate),
          source: 'feishu',
          sourceId: m.videoId,
        );

        // 插入指标数据
        await _db.upsertMetrics(
          videoId: videoId,
          playCount: m.playCount,
          likeCount: m.likeCount,
          commentCount: m.commentCount,
          shareCount: m.shareCount,
          collectCount: m.collectCount,
          finishRate: m.finishRate,
          avgWatchDuration: m.avgWatchDuration,
          twoSecondExitRate: m.twoSecondExitRate,
          coverCtr: m.coverCtr,
          profileVisits: m.profileVisits,
          fullPlayCount: m.fullPlayCount,
          fiveSecondFinishRate: m.fiveSecondFinishRate,
          newFollowers: m.newFollowers,
          totalDuration: m.totalDuration,
          trafficRecommend: m.trafficRecommend,
          trafficSearch: m.trafficSearch,
          trafficFollow: m.trafficFollow,
          trafficCity: m.trafficCity,
          trafficProfile: m.trafficProfile,
          trafficHotspot: m.trafficHotspot,
          trafficDoujia: m.trafficDoujia,
          audienceMaleRatio: m.audienceMaleRatio,
          audienceAgeDist: m.audienceAgeDist,
          audienceRegionDist: m.audienceRegionDist,
          audienceTgi: null,
          likeRate: m.likeRate,
          commentRate: m.commentRate,
          shareRate: m.shareRate,
          collectRate: m.collectRate,
          interactionRate: m.interactionRate,
          fetchedAt: now,
          source: 'feishu',
        );
        count++;
      }

      if (!mounted) return;
      setState(() {
        _importing = false;
        _importedCount = count;
      });

      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功导入 $count 条视频数据'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 解析日期字符串为时间戳
  int _parseDate(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now().millisecondsSinceEpoch;
    
    // 尝试解析数字时间戳
    final numVal = int.tryParse(dateStr);
    if (numVal != null) {
      if (numVal > 1e12) return numVal;
      if (numVal > 1e9) return numVal * 1000;
      return numVal;
    }
    
    // 尝试解析日期格式
    final dt = DateTime.tryParse(dateStr);
    if (dt != null) return dt.millisecondsSinceEpoch;
    
    return DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('飞书数据'),
        actions: [
          if (!_notConfigured && _metrics.isNotEmpty)
            IconButton(
              icon: _importing 
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              onPressed: _importing ? null : _importToDatabase,
              tooltip: '导入到本地数据库',
            ),
          if (!_notConfigured)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading || _importing ? null : _loadData,
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
