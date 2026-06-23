import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../data/database/database.dart';

/// 抖音 OAuth 授权服务
/// Token 与授权状态存储在本地 SQLite（douyin_auth 表）
class DouyinAuthService {
  final AppDatabase _db;

  DouyinAuthService({AppDatabase? db}) : _db = db ?? AppDatabase();

  // 存储 Key
  static const String _accessTokenKey = 'douyin_access_token';
  static const String _refreshTokenKey = 'douyin_refresh_token';
  static const String _openIdKey = 'douyin_open_id';
  static const String _expiresAtKey = 'douyin_token_expires_at';

  // ---- 授权 URL ----

  /// 生成抖音 OAuth 授权 URL
  String buildAuthUrl() {
    final scope = AppConstants.oauthScopes.join(',');
    return '${AppConstants.douyinOAuthBaseUrl}/platform/oauth/connect/'
        '?client_key=${AppConstants.douyinClientKey}'
        '&response_type=code'
        '&scope=$scope'
        '&redirect_uri=${Uri.encodeComponent(AppConstants.douyinRedirectUri)}';
  }

  /// 在浏览器中打开抖音授权页
  Future<bool> openAuthPage() async {
    final url = buildAuthUrl();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  // ---- Token 管理 ----

  /// 通过授权码换取 access_token
  Future<DouyinAuthResult> exchangeCodeForToken(String code) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.douyinOAuthBaseUrl}/oauth/access_token/')
            .replace(queryParameters: {
          'client_key': AppConstants.douyinClientKey,
          'client_secret': AppConstants.douyinClientSecret,
          'code': code,
          'grant_type': 'authorization_code',
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['data'] != null && body['data']['error_code'] == null) {
          final data = body['data'];
          final accessToken = data['access_token'] as String;
          final refreshToken = data['refresh_token'] as String;
          final openId = data['open_id'] as String;
          final expiresIn = data['expires_in'] as int? ?? 86400;
          final expiresAt =
              DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);

          await Future.wait([
            _db.setDouyinAuth(_accessTokenKey, accessToken),
            _db.setDouyinAuth(_refreshTokenKey, refreshToken),
            _db.setDouyinAuth(_openIdKey, openId),
            _db.setDouyinAuth(_expiresAtKey, expiresAt.toString()),
          ]);

          return DouyinAuthResult(
            success: true,
            openId: openId,
            accessToken: accessToken,
          );
        }
        return DouyinAuthResult(
          success: false,
          error: body['data']?['description'] ?? '授权失败',
        );
      }
      return DouyinAuthResult(
        success: false,
        error: '网络请求失败: HTTP ${response.statusCode}',
      );
    } catch (e) {
      return DouyinAuthResult(success: false, error: e.toString());
    }
  }

  /// 刷新 access_token
  Future<bool> refreshAccessToken() async {
    final refreshToken = await _db.getDouyinAuth(_refreshTokenKey);
    if (refreshToken == null) return false;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.douyinOAuthBaseUrl}/oauth/refresh_token/')
            .replace(queryParameters: {
          'client_key': AppConstants.douyinClientKey,
          'refresh_token': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['data'] != null) {
          final data = body['data'];
          final newToken = data['access_token'] as String;
          final expiresIn = data['expires_in'] as int? ?? 86400;
          final expiresAt =
              DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);

          await _db.setDouyinAuth(_accessTokenKey, newToken);
          await _db.setDouyinAuth(_expiresAtKey, expiresAt.toString());

          if (data['refresh_token'] != null) {
            await _db.setDouyinAuth(
                _refreshTokenKey, data['refresh_token']);
          }
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// 获取有效的 access_token（自动刷新过期 token）
  Future<String?> getValidAccessToken() async {
    final expiresAtStr = await _db.getDouyinAuth(_expiresAtKey);
    if (expiresAtStr == null) return null;

    final expiresAt = int.tryParse(expiresAtStr) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      final refreshed = await refreshAccessToken();
      if (!refreshed) return null;
    }
    return await _db.getDouyinAuth(_accessTokenKey);
  }

  /// 检查是否已授权且 token 有效
  Future<bool> isAuthorized() async {
    final token = await getValidAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// 清除授权数据
  Future<void> clearAuth() async {
    await Future.wait([
      _db.deleteDouyinAuth(_accessTokenKey),
      _db.deleteDouyinAuth(_refreshTokenKey),
      _db.deleteDouyinAuth(_openIdKey),
      _db.deleteDouyinAuth(_expiresAtKey),
    ]);
  }

  /// 获取已授权 openId
  Future<String?> getOpenId() async {
    return await _db.getDouyinAuth(_openIdKey);
  }
}

/// 授权结果
class DouyinAuthResult {
  final bool success;
  final String? openId;
  final String? accessToken;
  final String? error;

  DouyinAuthResult({
    required this.success,
    this.openId,
    this.accessToken,
    this.error,
  });
}
