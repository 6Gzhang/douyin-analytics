import 'package:flutter/material.dart';
import 'router.dart';
import 'core/theme.dart';

class DyAnalyticsApp extends StatelessWidget {
  const DyAnalyticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DyAnalytics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: goRouter,
    );
  }
}
