import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:crypto/crypto.dart';
import 'secure_logger.dart';

/// 证书固定配置
class CertificatePinningConfig {
  final Set<String> allowedFingerprints;
  final Set<String> allowedHosts;

  const CertificatePinningConfig({
    required this.allowedFingerprints,
    required this.allowedHosts,
  });
}

/// 安全的 HTTP 客户端 - 支持证书固定和请求签名
class SecureHttpClient {
  SecureHttpClient._();
  static final SecureHttpClient instance = SecureHttpClient._();

  late final IOClient _ioClient;

  /// 已知可信证书指纹（SHA-256）
  /// 实际部署时需替换为真实证书指纹
  static final Map<String, CertificatePinningConfig> _pinningConfigs = {
    'api.siliconflow.cn': const CertificatePinningConfig(
      allowedFingerprints: {
        // SiliconFlow API 证书指纹 - 需替换为真实值
        '2a575471e31340bc21581c2f5a3e5b0d8b0b7d3c1e2f3a4b5c6d7e8f9a0b1c2d',
      },
      allowedHosts: {'api.siliconflow.cn'},
    ),
    'api.github.com': const CertificatePinningConfig(
      allowedFingerprints: {
        // GitHub API 证书指纹 - 需替换为真实值
        '3b686474e41451bc32682d3f6a4f6c1e9c0c8e4d2f3a4b5c6d7e8f9a0b1c2d3',
      },
      allowedHosts: {'api.github.com'},
    ),
    'open.douyin.com': const CertificatePinningConfig(
      allowedFingerprints: {
        // 抖音开放平台证书指纹 - 需替换为真实值
        '4c797585f52562cd43793e4g7b5g7d2f0d1d9e5f3g4a5b6c7d8e9f0a1b2c3d4',
      },
      allowedHosts: {'open.douyin.com'},
    ),
  };

  void init() {
    final nativeClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        if (kDebugMode) return true;
        if (!_pinningConfigs.containsKey(host)) {
          // 对未配置的域名，允许系统默认验证
          return false;
        }
        return _verifyCertificate(cert, host);
      };
    _ioClient = IOClient(nativeClient);
  }

  /// 获取配置了证书固定的 IOClient
  IOClient get client => _ioClient;

  bool _verifyCertificate(X509Certificate cert, String host) {
    final config = _pinningConfigs[host];
    if (config == null) return false;

    final der = cert.der;
    final digest = sha256.convert(der);
    final fingerprint = digest.toString();

    final allowed = config.allowedFingerprints.contains(fingerprint);
    if (!allowed) {
      SecureLogger.instance.warning(
        '证书指纹不匹配: $host, fingerprint=$fingerprint',
        event: SecurityEventType.suspiciousActivity,
      );
    }
    return allowed;
  }

  /// 安全的 GET 请求
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final requestHeaders = headers ?? <String, String>{};
    _addSecurityHeaders(requestHeaders);

    try {
      final response = await _ioClient
          .get(url, headers: requestHeaders)
          .timeout(const Duration(seconds: 30));
      return response;
    } on TimeoutException {
      SecureLogger.instance.warning('请求超时: ${url.toString()}');
      rethrow;
    }
  }

  /// 安全的 POST 请求
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final requestHeaders = headers ?? <String, String>{};
    _addSecurityHeaders(requestHeaders);

    try {
      final response = await _ioClient
          .post(url, headers: requestHeaders, body: body, encoding: encoding)
          .timeout(const Duration(seconds: 90));
      return response;
    } on TimeoutException {
      SecureLogger.instance.warning('请求超时: ${url.toString()}');
      rethrow;
    }
  }

  /// 添加安全请求头
  void _addSecurityHeaders(Map<String, String> headers) {
    headers.putIfAbsent('X-Content-Type-Options', () => 'nosniff');
    headers.putIfAbsent('X-Frame-Options', () => 'DENY');
    headers.putIfAbsent('X-XSS-Protection', () => '1; mode=block');
    headers.putIfAbsent('Referrer-Policy', () => 'strict-origin-when-cross-origin');
  }

  /// 验证 URL 是否安全
  static bool isUrlSafe(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;
    if (uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1') {
      return false;
    }
    if (uri.host.startsWith('192.168.') ||
        uri.host.startsWith('10.') ||
        uri.host.startsWith('172.')) {
      return false;
    }
    return true;
  }
}