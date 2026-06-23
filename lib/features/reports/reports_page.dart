import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import 'trend_report_page.dart';
import 'audience_report_page.dart';
import 'content_insight_report_page.dart';
import 'retention_report_page.dart';
import 'publish_calendar_page.dart';
import 'title_analysis_page.dart';
import 'benchmark_report_page.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final List<_ReportItem> _reports = const [
    _ReportItem(
      title: '增长趋势',
      subtitle: '播放/粉丝走势',
      icon: Icons.trending_up,
      color: AppTheme.douyinRed,
    ),
    _ReportItem(
      title: '受众分析',
      subtitle: '粉丝画像深度',
      icon: Icons.people_outline,
      color: AppTheme.accentPurple,
    ),
    _ReportItem(
      title: '内容洞察',
      subtitle: '完播率/时长分布',
      icon: Icons.ondemand_video_outlined,
      color: AppTheme.accentGreen,
    ),
    _ReportItem(
      title: '留存分析',
      subtitle: '观看时长分布',
      icon: Icons.timelapse_outlined,
      color: AppTheme.accentBlue,
    ),
    _ReportItem(
      title: '发布日历',
      subtitle: '最佳发布时机',
      icon: Icons.calendar_month_outlined,
      color: AppTheme.accentAmber,
    ),
    _ReportItem(
      title: '标题分析',
      subtitle: '爆款关键词',
      icon: Icons.title,
      color: AppTheme.douyinCyan,
    ),
    _ReportItem(
      title: '对标分析',
      subtitle: '行业基准对比',
      icon: Icons.compare_outlined,
      color: Color(0xFFEC407A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据报告'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          itemCount: _reports.length,
          itemBuilder: (context, index) {
            return _buildReportCard(_reports[index], index);
          },
        ),
      ),
    );
  }

  Widget _buildReportCard(_ReportItem item, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _navigateTo(index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const Spacer(),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(int index) {
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TrendReportPage()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AudienceReportPage()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ContentInsightReportPage()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RetentionReportPage()),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PublishCalendarPage()),
        );
        break;
      case 5:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TitleAnalysisPage()),
        );
        break;
      case 6:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BenchmarkReportPage()),
        );
        break;
    }
  }
}

class _ReportItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ReportItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
