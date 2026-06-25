import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 日志级别
enum SecurityLogLevel { debug, info, warning, error, critical }

/// 安全事件类型
enum SecurityEventType {
  appLaunch,
  appLock,
  appUnlock,
  authSuccess,
  authFailure,
  apiKeySaved,
  apiKeyDeleted,
  dataCleared,
  dataExported,
  dataImported,
  updateChecked,
  updateDownloaded,
  unauthorizedAccess,
  suspiciousActivity,
}

/// 安全审计日志条目
class SecurityLogEntry {
  final DateTime timestamp;
  final SecurityLogLevel level;
  final SecurityEventType? eventType;
  final String message;
  final Map<String, String>? metadata;

  SecurityLogEntry({
    required this.timestamp,
    this.level = SecurityLogLevel.info,
    this.eventType,
    required this.message,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'event': eventType?.name,
        'message': message,
        'metadata': metadata,
      };

  @override
  String toString() {
    final parts = StringBuffer();
    parts.write('[${timestamp.toIso8601String()}] ');
    parts.write('[${level.name.toUpperCase()}] ');
    if (eventType != null) parts.write('[${eventType!.name}] ');
    parts.write(message);
    return parts.toString();
  }
}

/// 安全审计日志 - 记录关键操作，自动脱敏敏感信息
class SecureLogger {
  SecureLogger._();
  static final SecureLogger instance = SecureLogger._();

  final List<SecurityLogEntry> _logs = [];
  static const int _maxLogs = 500;

  // ---- 敏感信息脱敏模式 ----
  static final _sensitivePatterns = <RegExp>[
    RegExp(r'sk-[a-zA-Z0-9]{8,}'),
    RegExp(r'Bearer\s+[a-zA-Z0-9\-_\.]+'),
    RegExp(r'api_key[=:]\s*[a-zA-Z0-9\-_\.]+'),
    RegExp(r'access_token[=:]\s*[a-zA-Z0-9\-_\.]+'),
    RegExp(r'password[=:]\s*\S+'),
  ];

  /// 记录日志（自动脱敏）
  void log(
    String message, {
    SecurityLogLevel level = SecurityLogLevel.info,
    SecurityEventType? eventType,
    Map<String, String>? metadata,
  }) {
    final sanitized = _redactSensitiveData(message);
    final entry = SecurityLogEntry(
      timestamp: DateTime.now(),
      level: level,
      eventType: eventType,
      message: sanitized,
      metadata: metadata,
    );

    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeRange(0, _logs.length - _maxLogs);
    }

    // Debug 模式下输出到控制台
    if (level.index >= SecurityLogLevel.warning.index) {
      debugPrint(entry.toString());
    }
  }

  /// 获取最近的日志
  List<SecurityLogEntry> getRecentLogs({int count = 50}) {
    final start = _logs.length > count ? _logs.length - count : 0;
    return _logs.sublist(start).reversed.toList();
  }

  /// 获取指定事件类型的日志
  List<SecurityLogEntry> getLogsByEvent(SecurityEventType eventType) {
    return _logs.where((e) => e.eventType == eventType).toList();
  }

  /// 获取所有日志
  List<SecurityLogEntry> get allLogs => List.unmodifiable(_logs);

  /// 清空日志
  void clear() => _logs.clear();

  /// 导出日志为 JSON
  String exportToJson() {
    return jsonEncode(_logs.map((e) => e.toJson()).toList());
  }

  // ---- 便捷方法 ----

  void info(String msg, {SecurityEventType? event, Map<String, String>? meta}) =>
      log(msg, level: SecurityLogLevel.info, eventType: event, metadata: meta);

  void warning(String msg, {SecurityEventType? event, Map<String, String>? meta}) =>
      log(msg, level: SecurityLogLevel.warning, eventType: event, metadata: meta);

  void error(String msg, {SecurityEventType? event, Map<String, String>? meta}) =>
      log(msg, level: SecurityLogLevel.error, eventType: event, metadata: meta);

  void critical(String msg, {SecurityEventType? event, Map<String, String>? meta}) =>
      log(msg, level: SecurityLogLevel.critical, eventType: event, metadata: meta);

  // ---- 脱敏处理 ----

  String _redactSensitiveData(String input) {
    var result = input;
    for (final pattern in _sensitivePatterns) {
      result = result.replaceAllMapped(pattern, (match) {
        final matched = match.group(0)!;
        if (matched.length <= 12) return '***REDACTED***';
        return '${matched.substring(0, 4)}***REDACTED***${matched.substring(matched.length - 4)}';
      });
    }
    return result;
  }
}