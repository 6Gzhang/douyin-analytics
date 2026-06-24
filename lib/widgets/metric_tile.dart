import 'package:flutter/material.dart';

/// 指标卡片组件
class MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const MetricTile({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey[
                        isDark ? 500 : 400]),
              ],
            ),
            const Spacer(),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(subtitle!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ],
          ],
        ),
      ),
    );
  }
}
