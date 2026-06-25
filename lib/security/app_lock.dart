import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'security_service.dart';
import 'secure_logger.dart';

/// 应用锁管理类
class AppLockManager {
  AppLockManager._();
  static final AppLockManager instance = AppLockManager._();

  final _secureStorage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();
  static const String _pinKey = '_app_lock_pin_hash';
  static const String _lockEnabledKey = '_app_lock_enabled';
  static const String _bioEnabledKey = '_app_lock_bio_enabled';

  bool _isLocked = false;
  bool _isLockEnabled = false;
  bool _isBioEnabled = false;
  Timer? _autoLockTimer;

  bool get isLocked => _isLocked;
  bool get isLockEnabled => _isLockEnabled;
  bool get isBioEnabled => _isBioEnabled;

  /// 初始化锁状态
  Future<void> init() async {
    final enabled = await _secureStorage.read(key: _lockEnabledKey);
    _isLockEnabled = enabled == 'true';
    final bio = await _secureStorage.read(key: _bioEnabledKey);
    _isBioEnabled = bio == 'true';
  }

  /// 设置 PIN 码
  Future<bool> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 8) return false;
    if (!RegExp(r'^\d+$').hasMatch(pin)) return false;
    final hash = SecurityService.instance.sha256(pin);
    await _secureStorage.write(key: _pinKey, value: hash);
    await _secureStorage.write(key: _lockEnabledKey, value: 'true');
    _isLockEnabled = true;
    SecureLogger.instance.info('PIN 锁已设置', event: SecurityEventType.appLock);
    return true;
  }

  /// 验证 PIN
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _pinKey);
    if (storedHash == null) return true; // 未设置 PIN 则允许
    final inputHash = SecurityService.instance.sha256(pin);
    final result = inputHash == storedHash;
    if (result) {
      SecureLogger.instance.info('PIN 验证成功', event: SecurityEventType.appUnlock);
    } else {
      SecureLogger.instance.warning('PIN 验证失败', event: SecurityEventType.authFailure);
    }
    return result;
  }

  /// 启用/禁用锁
  Future<void> setLockEnabled(bool enabled) async {
    _isLockEnabled = enabled;
    await _secureStorage.write(key: _lockEnabledKey, value: enabled.toString());
    if (!enabled) {
      _isLocked = false;
      _autoLockTimer?.cancel();
    }
    SecureLogger.instance.info(
      enabled ? '应用锁已启用' : '应用锁已禁用',
      event: SecurityEventType.appLock,
    );
  }

  /// 启用/禁用生物识别
  Future<void> setBioEnabled(bool enabled) async {
    _isBioEnabled = enabled;
    await _secureStorage.write(key: _bioEnabledKey, value: enabled.toString());
  }

  /// 检查生物识别是否可用
  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// 生物识别认证
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: '请验证身份以解锁应用',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// 锁定应用
  void lock() {
    _isLocked = true;
    SecureLogger.instance.info('应用已锁定', event: SecurityEventType.appLock);
  }

  /// 解锁应用
  void unlock() {
    _isLocked = false;
    _autoLockTimer?.cancel();
  }

  /// 启动自动锁屏计时器
  void startAutoLockTimer({Duration duration = const Duration(minutes: 5)}) {
    _autoLockTimer?.cancel();
    _autoLockTimer = Timer(duration, () {
      if (_isLockEnabled && !_isLocked) {
        lock();
      }
    });
  }

  /// 重置自动锁屏计时器（用户活动时调用）
  void resetAutoLockTimer() {
    if (!_isLockEnabled || _isLocked) return;
    _autoLockTimer?.cancel();
    startAutoLockTimer();
  }

  /// 移除 PIN
  Future<void> removePin() async {
    await _secureStorage.delete(key: _pinKey);
    await _secureStorage.write(key: _lockEnabledKey, value: 'false');
    _isLockEnabled = false;
    _isLocked = false;
    _autoLockTimer?.cancel();
    SecureLogger.instance.info('PIN 锁已移除', event: SecurityEventType.appLock);
  }

  void dispose() {
    _autoLockTimer?.cancel();
  }
}

/// 应用锁屏页面
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  final _pinController = TextEditingController();
  String _error = '';
  bool _verifying = false;
  int _failedAttempts = 0;
  DateTime? _lastFailedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tryBiometric();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    if (!AppLockManager.instance.isBioEnabled) return;
    final success = await AppLockManager.instance.authenticateWithBiometrics();
    if (success && mounted) {
      AppLockManager.instance.unlock();
      widget.onUnlocked();
    }
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text;
    if (pin.length < 4) {
      setState(() => _error = 'PIN 至少4位数字');
      return;
    }

    // 失败次数限制
    if (_failedAttempts >= 5 && _lastFailedTime != null) {
      final elapsed = DateTime.now().difference(_lastFailedTime!);
      if (elapsed.inSeconds < 30) {
        setState(() => _error = '尝试次数过多，请等待 ${30 - elapsed.inSeconds} 秒');
        return;
      }
      _failedAttempts = 0;
    }

    setState(() => _verifying = true);
    final success = await AppLockManager.instance.verifyPin(pin);
    setState(() => _verifying = false);

    if (success) {
      _failedAttempts = 0;
      AppLockManager.instance.unlock();
      widget.onUnlocked();
    } else {
      _failedAttempts++;
      _lastFailedTime = DateTime.now();
      _pinController.clear();
      setState(() => _error = 'PIN 错误，剩余尝试 ${5 - _failedAttempts} 次');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 锁图标
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'DyAnalytics',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请输入 PIN 码解锁',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                // PIN 输入
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _pinController,
                    obscureText: true,
                    maxLength: 8,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (_) {
                      if (_error.isNotEmpty) setState(() => _error = '');
                    },
                    onSubmitted: (_) => _verifyPin(),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // 解锁按钮
                SizedBox(
                  width: 200,
                  height: 48,
                  child: FilledButton(
                    onPressed: _verifying ? null : _verifyPin,
                    child: _verifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('解锁', style: TextStyle(fontSize: 16)),
                  ),
                ),
                if (AppLockManager.instance.isBioEnabled) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _tryBiometric,
                    icon: const Icon(Icons.fingerprint, size: 20),
                    label: const Text('使用指纹/面容解锁'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}