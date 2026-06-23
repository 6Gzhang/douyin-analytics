import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format_utils.dart';
import '../../data/database/database.dart';

class VideoListPage extends ConsumerStatefulWidget {
  const VideoListPage({super.key});

  @override
  ConsumerState<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends ConsumerState<VideoListPage> {
  final _db = AppDatabase();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _videos = [];
  String _orderBy = 'time';

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String? orderBy;
      if (_orderBy == 'plays') orderBy = 'plays';
      if (_orderBy == 'likes') orderBy = 'likes';
      final videos = await _db.getAllVideosWithMetrics(orderBy: orderBy);
      if (!mounted) return;
      setState(() {
        _videos = videos;
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
        title: const Text('视频列表'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadVideos),
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
            Text(_error!, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadVideos, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无视频数据',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('请通过设置页导入 CSV 数据',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSortBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadVideos,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _videos.length,
              itemBuilder: (context, index) => _buildVideoCard(_videos[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _sortChip('按时间', 'time'),
          const SizedBox(width: 8),
          _sortChip('按播放', 'plays'),
          const SizedBox(width: 8),
          _sortChip('按点赞', 'likes'),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    final selected = _orderBy == value;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) {
        setState(() => _orderBy = value);
        _loadVideos();
      },
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> v) {
    final title = v['title'] as String? ?? '无标题';
    final playCount = (v['play_count'] as int?) ?? 0;
    final likeCount = (v['like_count'] as int?) ?? 0;
    final createTime = v['create_time'] as int?;
    final date = createTime != null && createTime > 0
        ? DateTime.fromMillisecondsSinceEpoch(createTime * 1000)
            .toString()
            .substring(0, 16)
        : '--';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(date,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _statChip(Icons.play_arrow, formatCount(playCount)),
                      const SizedBox(width: 12),
                      _statChip(Icons.favorite, formatCount(likeCount)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[500]),
        const SizedBox(width: 2),
        Text(text,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}
