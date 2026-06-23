import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

/// OAuth Token 管理器
class OAuthManager {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 存储 Token
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String openId,
    required int expiresIn,
  }) async {
    final expiresAt = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
    await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
    await _storage.write(key: AppConstants.openIdKey, value: openId);
    await _storage.write(key: AppConstants.expiresAtKey, value: expiresAt.toString());
  }

  // 获取 Access Token
  Future<String?> getAccessToken() async {
    final expiresAtStr = await _storage.read(key: AppConstants.expiresAtKey);
    if (expiresAtStr == null) return null;

    final expiresAt = int.tryParse(expiresAtStr) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      return await _refreshAccessToken();
    }
    return await _storage.read(key: AppConstants.accessTokenKey);
  }

  // 获取 Open ID
  Future<String?> getOpenId() async {
    return await _storage.read(key: AppConstants.openIdKey);
  }

  // 刷新 Token
  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
    if (refreshToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.douyinOAuthBaseUrl}/oauth/refresh_token/')
            .replace(queryParameters: {
          'client_key': AppConstants.douyinClientKey,
          'refresh_token': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final newAccessToken = data['access_token'];
        final expiresIn = data['expires_in'];
        final expiresAt = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);

        await _storage.write(key: AppConstants.accessTokenKey, value: newAccessToken);
        await _storage.write(key: AppConstants.expiresAtKey, value: expiresAt.toString());

        // 如果有新的 refresh_token 也更新
        if (data['refresh_token'] != null) {
          await _storage.write(key: AppConstants.refreshTokenKey, value: data['refresh_token']);
        }
        return newAccessToken;
      }
    } catch (_) {}
    return null;
  }

  // 判断是否已授权
  Future<bool> isAuthorized() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // 清除 Token（解绑）
  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.openIdKey);
    await _storage.delete(key: AppConstants.expiresAtKey);
  }

  // 生成授权 URL
  String generateAuthUrl() {
    final scope = AppConstants.oauthScopes.join(',');
    return '${AppConstants.douyinOAuthBaseUrl}/platform/oauth/connect/'
        '?client_key=${AppConstants.douyinClientKey}'
        '&response_type=code'
        '&scope=$scope'
        '&redirect_uri=${Uri.encodeComponent(AppConstants.douyinRedirectUri)}';
  }

  // 通过授权码换取 Token
  Future<bool> exchangeCodeForToken(String code) async {
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
        final data = jsonDecode(response.body)['data'];
        await saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          openId: data['open_id'],
          expiresIn: data['expires_in'] ?? 86400,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }
}
