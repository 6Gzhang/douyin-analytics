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
import 'traffic_source_page.dart';
import 'cover_analysis_page.dart';
import 'viral_gene_analysis_page.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final List<_ReportItem> _reports = const [
    _ReportItem(title: '爆款基因', subtitle: '高播放视频特征分析', icon: Icons.bolt, color: Color(0xFFFF6D00)),
    _ReportItem(title: '增长趋势', subtitle: '播放/粉丝走势分析', icon: Icons.trending_up, color: AppTheme.douyinRed),
    _ReportItem(title: '受众分析', subtitle: '粉丝画像深度解读', icon: Icons.people_outline, color: AppTheme.accentPurple),
    _ReportItem(title: '内容洞察', subtitle: '完播率/时长分布', icon: Icons.ondemand_video_outlined, color: AppTheme.accentGreen),
    _ReportItem(title: '留存分析', subtitle: '秒级留存曲线', icon: Icons.timelapse_outlined, color: AppTheme.accentBlue),
    _ReportItem(title: '流量来源', subtitle: '推荐/搜索/关注', icon: Icons.traffic_outlined, color: AppTheme.accentAmber),
    _ReportItem(title: '封面分析', subtitle: '封面CTR优化', icon: Icons.image_outlined, color: AppTheme.douyinCyan),
    _ReportItem(title: '标题分析', subtitle: '爆款关键词库', icon: Icons.title, color: Color(0xFFEC407A)),
    _ReportItem(title: '发布日历', subtitle: '最佳发布时机', icon: Icons.calendar_month_outlined, color: Color(0xFF8D6E63)),
    _ReportItem(title: '对标分析', subtitle: '行业基准对比', icon: Icons.compare_outlined, color: Color(0xFF7E57C2)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据报告'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _navigateTo(index),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
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
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(int index) {
    Widget page;
    switch (index) {
      case 0:
        page = const ViralGeneAnalysisPage();
        break;
      case 1:
        page = const TrendReportPage();
        break;
      case 2:
        page = const AudienceReportPage();
        break;
      case 3:
        page = const ContentInsightReportPage();
        break;
      case 4:
        page = const RetentionReportPage();
        break;
      case 5:
        page = const TrafficSourcePage();
        break;
      case 6:
        page = const CoverAnalysisPage();
        break;
      case 7:
        page = const TitleAnalysisPage();
        break;
      case 8:
        page = const PublishCalendarPage();
        break;
      case 9:
        page = const BenchmarkReportPage();
        break;
      default:
        return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
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
