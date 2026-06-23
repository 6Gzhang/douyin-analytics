import 'package:flutter/material.dart';
import '../core/format_utils.dart';

/// 视频卡片组件
class VideoCard extends StatelessWidget {
  final String? coverUrl;
  final String title;
  final String createTime;
  final int playCount;
  final int likeCount;
  final int commentCount;
  final VoidCallback? onTap;

  const VideoCard({
    super.key,
    this.coverUrl,
    required this.title,
    required this.createTime,
    required this.playCount,
    required this.likeCount,
    required this.commentCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // 封面
            Container(
              width: 100,
              height: 140,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: coverUrl != null
                  ? Image.network(coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                  : const Center(child: Icon(Icons.play_circle_outline, size: 32, color: Colors.white54)),
            ),
            // 信息
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(createTime, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStat(Icons.play_arrow, formatCount(playCount)),
                        const SizedBox(width: 12),
                        _buildStat(Icons.favorite, formatCount(likeCount)),
                        const SizedBox(width: 12),
                        _buildStat(Icons.chat_bubble_outline, formatCount(commentCount)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 2),
        Text(value, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
