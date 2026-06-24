import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format_utils.dart';
import '../../data/database/database.dart';
import '../../utils/video_quality_analyzer.dart';

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
  List<Map<String, dynamic>> _filteredVideos = [];
  String _orderBy = 'quality';
  String _gradeFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  String _getGrade(double score) {
    return VideoQualityAnalyzer.getQualityGrade(score).name.toUpperCase();
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'S': return Color(0xFF9C27B0);
      case 'A': return Color(0xFF4CAF50);
      case 'B': return Color(0xFF2196F3);
      case 'C': return Color(0xFFFF9800);
      case 'D': return Color(0xFFF44336);
      default: return Colors.grey;
    }
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await _db.getAllVideosWithMetrics();
      // 计算质量评分并排序
      final withScores = videos.map((v) {
        final score = _getQualityScore(v);
        return {...v, 'quality_score': score, 'grade': _getGrade(score)};
      }).toList();

      // 排序
      withScores.sort((a, b) {
        switch (_orderBy) {
          case 'quality':
            return (b['quality_score'] as double).compareTo(a['quality_score'] as double);
          case 'plays':
            return ((b['play_count'] as int?) ?? 0).compareTo((a['play_count'] as int?) ?? 0);
          case 'likes':
            return ((b['like_count'] as int?) ?? 0).compareTo((a['like_count'] as int?) ?? 0);
          case 'comments':
            return ((b['comment_count'] as int?) ?? 0).compareTo((a['comment_count'] as int?) ?? 0);
          case 'shares':
            return ((b['share_count'] as int?) ?? 0).compareTo((a['share_count'] as int?) ?? 0);
          case 'finish_rate':
            return ((b['finish_rate'] as double?) ?? 0.0).compareTo((a['finish_rate'] as double?) ?? 0.0);
          case 'interaction':
            final aInt = _interactionRate(a);
            final bInt = _interactionRate(b);
            return bInt.compareTo(aInt);
          case 'time':
          default:
            return ((b['create_time'] as int?) ?? 0).compareTo((a['create_time'] as int?) ?? 0);
        }
      });

      if (!mounted) return;
      setState(() {
        _videos = withScores;
        _applyFilters();
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

  double _interactionRate(Map<String, dynamic> v) {
    final plays = (v['play_count'] as int?) ?? 0;
    if (plays == 0) return 0;
    final likes = (v['like_count'] as int?) ?? 0;
    final comments = (v['comment_count'] as int?) ?? 0;
    final shares = (v['share_count'] as int?) ?? 0;
    final collects = (v['collect_count'] as int?) ?? 0;
    return (likes + comments + shares + collects) / plays * 100;
  }

  void _applyFilters() {
    var filtered = List<Map<String, dynamic>>.from(_videos);

    // 等级筛选
    if (_gradeFilter != 'all') {
      filtered = filtered.where((v) => v['grade'] == _gradeFilter).toList();
    }

    // 搜索筛选
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((v) {
        final title = (v['title'] as String? ?? '').toLowerCase();
        return title.contains(query);
      }).toList();
    }

    _filteredVideos = filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频列表'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadVideos),
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
        _buildSearchBar(),
        _buildFilterBar(),
        _buildSortBar(),
        _buildStatsBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadVideos,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredVideos.length,
              itemBuilder: (context, index) => _buildVideoCard(_filteredVideos[index], index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() => _applyFilters()),
          decoration: InputDecoration(
            hintText: '搜索视频标题...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[500]),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _gradeChip('全部', 'all'),
            const SizedBox(width: 6),
            _gradeChip('S级', 'S'),
            const SizedBox(width: 6),
            _gradeChip('A级', 'A'),
            const SizedBox(width: 6),
            _gradeChip('B级', 'B'),
            const SizedBox(width: 6),
            _gradeChip('C级', 'C'),
            const SizedBox(width: 6),
            _gradeChip('D级', 'D'),
          ],
        ),
      ),
    );
  }

  Widget _gradeChip(String label, String value) {
    final selected = _gradeFilter == value;
    final color = value == 'all' ? Colors.grey : _getGradeColor(value);
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      selected: selected,
      selectedColor: color.withOpacity(0.15),
      checkmarkColor: color,
      labelStyle: TextStyle(color: selected ? color : Colors.grey[600]),
      side: BorderSide(color: selected ? color : Colors.grey[300]!),
      onSelected: (_) {
        setState(() => _gradeFilter = value);
        _applyFilters();
      },
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _sortChip('质量', 'quality'),
            const SizedBox(width: 6),
            _sortChip('时间', 'time'),
            const SizedBox(width: 6),
            _sortChip('播放', 'plays'),
            const SizedBox(width: 6),
            _sortChip('点赞', 'likes'),
            const SizedBox(width: 6),
            _sortChip('评论', 'comments'),
            const SizedBox(width: 6),
            _sortChip('分享', 'shares'),
            const SizedBox(width: 6),
            _sortChip('完播率', 'finish_rate'),
            const SizedBox(width: 6),
            _sortChip('互动率', 'interaction'),
          ],
        ),
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

  Widget _buildStatsBar() {
    final total = _videos.length;
    final sCount = _videos.where((v) => v['grade'] == 'S').length;
    final aCount = _videos.where((v) => v['grade'] == 'A').length;
    final avgScore = total > 0
        ? _videos.map((v) => v['quality_score'] as double).reduce((a, b) => a + b) / total
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[50],
      child: Row(
        children: [
          _statItem('共 $total 条', Colors.grey[700]!),
          _divider(),
          _statItem('平均 ${avgScore.toStringAsFixed(1)}分', Color(0xFF4CAF50)),
          _divider(),
          _statItem('S级 $sCount', Color(0xFF9C27B0)),
          _divider(),
          _statItem('A级 $aCount', Color(0xFF4CAF50)),
        ],
      ),
    );
  }

  Widget _statItem(String text, Color color) {
    return Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500));
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(width: 1, height: 10, color: Colors.grey[300]),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> v, int index) {
    final title = v['title'] as String? ?? '无标题';
    final playCount = (v['play_count'] as int?) ?? 0;
    final likeCount = (v['like_count'] as int?) ?? 0;
    final commentCount = (v['comment_count'] as int?) ?? 0;
    final shareCount = (v['share_count'] as int?) ?? 0;
    final finishRate = (v['finish_rate'] as double?) ?? 0.0;
    final qualityScore = (v['quality_score'] as double?) ?? 0.0;
    final grade = v['grade'] as String? ?? '-';
    final createTime = v['create_time'] as int?;
    final date = createTime != null && createTime > 0
        ? DateTime.fromMillisecondsSinceEpoch(createTime * 1000)
            .toString()
            .substring(0, 16)
        : '--';

    final gradeColor = _getGradeColor(grade);

    return InkWell(
      onTap: () {
        final videoId = v['video_id'] as String?;
        if (videoId != null) {
          context.push('/video/$videoId');
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 排名和质量分
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: gradeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '#${index + 1}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: gradeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        grade,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      qualityScore.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: gradeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 内容
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _statMini(Icons.play_arrow, formatCount(playCount), Colors.grey[600]!),
                        const SizedBox(width: 12),
                        _statMini(Icons.favorite, formatCount(likeCount), Colors.red[400]!),
                        const SizedBox(width: 12),
                        _statMini(Icons.comment, formatCount(commentCount), Colors.blue[400]!),
                        const SizedBox(width: 12),
                        _statMini(Icons.share, formatCount(shareCount), Colors.green[400]!),
                        const SizedBox(width: 12),
                        _statMini(Icons.percent, '${finishRate.toStringAsFixed(1)}%', Colors.orange[400]!),
                      ],
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
  }

  Widget _statMini(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
