import 'dart:async';
import 'package:flutter/material.dart';

/// 自动锁屏管理器 - 监听用户活动，超时自动锁定
class AutoLockManager extends WidgetsBindingObserver {
  AutoLockManager._();
  static final AutoLockManager instance = AutoLockManager._();

  Timer? _timer;
  VoidCallback? _onLock;
  Duration _timeout = const Duration(minutes: 5);
  DateTime _lastActivity = DateTime.now();

  Duration get timeout => _timeout;
  Duration get remainingTime {
    final elapsed = DateTime.now().difference(_lastActivity);
    return _timeout - elapsed;
  }

  bool get isExpired => remainingTime <= Duration.zero;

  /// 初始化自动锁屏
  void init({
    required VoidCallback onLock,
    Duration timeout = const Duration(minutes: 5),
  }) {
    _onLock = onLock;
    _timeout = timeout;
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  /// 设置超时时间
  void setTimeout(Duration duration) {
    _timeout = duration;
    _timer?.cancel();
    _startTimer();
  }

  /// 记录用户活动
  void recordActivity() {
    _lastActivity = DateTime.now();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (isExpired) {
        _timer?.cancel();
        _onLock?.call();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastActivity = DateTime.now();
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// 监听用户活动的包装 Widget
class ActivityListener extends StatefulWidget {
  final Widget child;
  final VoidCallback onActivity;

  const ActivityListener({
    super.key,
    required this.child,
    required this.onActivity,
  });

  @override
  State<ActivityListener> createState() => _ActivityListenerState();
}

class _ActivityListenerState extends State<ActivityListener> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onActivity,
      onPanDown: (_) => widget.onActivity,
      child: widget.child,
    );
  }
}