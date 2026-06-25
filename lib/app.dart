import 'package:flutter/material.dart';
import 'router.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'security/security.dart';

class DyAnalyticsApp extends StatefulWidget {
  const DyAnalyticsApp({super.key});

  @override
  State<DyAnalyticsApp> createState() => _DyAnalyticsAppState();
}

class _DyAnalyticsAppState extends State<DyAnalyticsApp>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSecurity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLockManager.instance.dispose();
    AutoLockManager.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        AppLockManager.instance.isLockEnabled) {
      AppLockManager.instance.lock();
      setState(() => _isLocked = true);
    }
  }

  Future<void> _initSecurity() async {
    await AppLockManager.instance.init();
    SecureHttpClient.instance.init();

    AutoLockManager.instance.init(
      onLock: () {
        if (AppLockManager.instance.isLockEnabled) {
          AppLockManager.instance.lock();
          setState(() => _isLocked = true);
        }
      },
      timeout: AppConstants.defaultAutoLockTimeout,
    );

    SecureLogger.instance.info(
      '应用启动',
      event: SecurityEventType.appLaunch,
      meta: {'version': AppConstants.appVersion},
    );

    setState(() => _initialized = true);
  }

  void _onUnlocked() {
    setState(() => _isLocked = false);
    AutoLockManager.instance.recordActivity();
  }

  void _onUserActivity() {
    AutoLockManager.instance.recordActivity();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_isLocked && AppLockManager.instance.isLockEnabled) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: LockScreen(onUnlocked: _onUnlocked),
      );
    }

    return ActivityListener(
      onActivity: _onUserActivity,
      child: MaterialApp.router(
        title: 'DyAnalytics',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: goRouter,
      ),
    );
  }
}