import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/video_list/video_list_page.dart';
import 'features/video_detail/video_detail_page.dart';
import 'features/reports/reports_page.dart';
import 'features/reports/trend_report_page.dart';
import 'features/reports/audience_report_page.dart';
import 'features/reports/content_insight_report_page.dart';
import 'features/reports/benchmark_report_page.dart';
import 'features/reports/title_analysis_page.dart';
import 'features/reports/publish_calendar_page.dart';
import 'features/reports/retention_report_page.dart';
import 'features/reports/traffic_source_page.dart';
import 'features/reports/cover_analysis_page.dart';
import 'features/ai_assistant/ai_assistant_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/auto_sync_settings_page.dart';

final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/videos', builder: (_, __) => const VideoListPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/reports', builder: (_, __) => const ReportsPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        ]),
      ],
    ),
    GoRoute(path: '/video/:id', builder: (_, state) {
      return VideoDetailPage(videoId: state.pathParameters['id']!);
    }),
    GoRoute(path: '/report/trend', builder: (_, __) => const TrendReportPage()),
    GoRoute(path: '/report/audience', builder: (_, __) => const AudienceReportPage()),
    GoRoute(path: '/report/content', builder: (_, __) => const ContentInsightReportPage()),
    GoRoute(path: '/report/benchmark', builder: (_, __) => const BenchmarkReportPage()),
    GoRoute(path: '/report/title', builder: (_, __) => const TitleAnalysisPage()),
    GoRoute(path: '/report/calendar', builder: (_, __) => const PublishCalendarPage()),
    GoRoute(path: '/report/retention', builder: (_, __) => const RetentionReportPage()),
    GoRoute(path: '/report/traffic', builder: (_, __) => const TrafficSourcePage()),
    GoRoute(path: '/report/cover', builder: (_, __) => const CoverAnalysisPage()),
    GoRoute(path: '/ai-assistant', builder: (_, __) => const AiAssistantPage()),
    GoRoute(path: '/settings/auto-sync', builder: (_, __) => const AutoSyncSettingsPage()),
  ],
);

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(index,
              initialLocation: index == navigationShell.currentIndex);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: '概览'),
          NavigationDestination(
              icon: Icon(Icons.video_library_outlined),
              selectedIcon: Icon(Icons.video_library),
              label: '视频'),
          NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: '分析'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设置'),
        ],
      ),
    );
  }
}
