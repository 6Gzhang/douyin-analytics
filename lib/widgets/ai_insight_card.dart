import 'package:flutter/material.dart';

/// AI 分析建议卡片
class AiInsightCard extends StatelessWidget {
  final String? insight;
  final List<String>? strengths;
  final List<String>? weaknesses;
  final List<String>? suggestions;

  const AiInsightCard({
    super.key,
    this.insight,
    this.strengths,
    this.weaknesses,
    this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFE2C55), Color(0xFF25F4EE)],
                    ),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                const Text('AI 分析', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),

            // 分析内容
            if (insight != null) ...[
              Text(insight!, style: const TextStyle(fontSize: 14, height: 1.5)),
            ] else ...[
              Text('暂无 AI 分析结果', style: TextStyle(color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text(
                '同步视频数据后，AI 将自动分析每条视频的表现并给出优化建议',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],

            // 优缺点
            if (strengths != null && strengths!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildList('优势', strengths!, Colors.green),
            ],
            if (weaknesses != null && weaknesses!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildList('不足', weaknesses!, Colors.orange),
            ],
            if (suggestions != null && suggestions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildList('建议', suggestions!, primaryColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildList(String label, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color)),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('· ', style: TextStyle(color: color, fontSize: 14)),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
            ],
          ),
        )),
      ],
    );
  }
}
