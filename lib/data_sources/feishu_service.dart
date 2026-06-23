import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../data/database/database.dart';

/// 飞书 Open API 服务 - 读取多维表格中的抖音数据
/// 配置存储在本地 SQLite（feishu_config 表）
class FeishuService {
  static const String _baseUrl = 'https://open.feishu.cn';

  final AppDatabase _db;
  FeishuService(this._db);

  // 配置存储 Key
  static const String _appIdKey = 'feishu_app_id';
  static const String _appSecretKey = 'feishu_app_secret';
  static const String _appTokenKey = 'feishu_app_token';
  static const String _tableIdKey = 'feishu_table_id';
  static const String _tenantTokenKey = 'feishu_tenant_token';
  static const String _tokenExpiresAtKey = 'feishu_token_expires_at';

  // ---- 配置管理 ----

  Future<void> saveConfig({
    required String appId,
    required String appSecret,
    required String appToken,
    required String tableId,
  }) async {
    await Future.wait([
      _db.setFeishuConfig(_appIdKey, appId),
      _db.setFeishuConfig(_appSecretKey, appSecret),
      _db.setFeishuConfig(_appTokenKey, appToken),
      _db.setFeishuConfig(_tableIdKey, tableId),
    ]);
    // 清除旧 token，下次 API 调用时自动刷新
    await _db.deleteFeishuConfig(_tenantTokenKey);
    await _db.deleteFeishuConfig(_tokenExpiresAtKey);
  }

  Future<FeishuConfig?> loadConfig() async {
    final appId = await _db.getFeishuConfig(_appIdKey);
    final appSecret = await _db.getFeishuConfig(_appSecretKey);
    final appToken = await _db.getFeishuConfig(_appTokenKey);
    final tableId = await _db.getFeishuConfig(_tableIdKey);
    if (appId == null || appSecret == null || appToken == null || tableId == null) {
      return null;
    }
    return FeishuConfig(
      appId: appId,
      appSecret: appSecret,
      appToken: appToken,
      tableId: tableId,
    );
  }

  /// 获取已保存的配置值（单项，供设置页展示）
  Future<String?> getConfigValue(String key) async {
    return await _db.getFeishuConfig(key);
  }

  Future<bool> isConfigured() async {
    final config = await loadConfig();
    return config != null;
  }

  // ---- 认证 ----

  Future<String> _getTenantAccessToken() async {
    // 检查缓存
    final expiresStr = await _db.getFeishuConfig(_tokenExpiresAtKey);
    if (expiresStr != null) {
      final expiresAt = int.tryParse(expiresStr) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < expiresAt - 300000) {
        final cached = await _db.getFeishuConfig(_tenantTokenKey);
        if (cached != null && cached.isNotEmpty) return cached;
      }
    }

    // 请求新 token
    final config = await loadConfig();
    if (config == null) throw FeishuException('飞书配置未完成');

    final response = await http.post(
      Uri.parse('$_baseUrl/open-apis/auth/v3/tenant_access_token/internal'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'app_id': config.appId,
        'app_secret': config.appSecret,
      }),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['code'] == 0) {
        final token = body['tenant_access_token'] as String;
        final expire = body['expire'] as int; // 秒
        final expiresAt =
            DateTime.now().millisecondsSinceEpoch + (expire * 1000);
        await _db.setFeishuConfig(_tenantTokenKey, token);
        await _db.setFeishuConfig(_tokenExpiresAtKey, expiresAt.toString());
        return token;
      }
      throw FeishuException('获取飞书 token 失败: ${body['msg']}');
    }
    throw FeishuException('飞书 API 请求失败: HTTP ${response.statusCode}');
  }

  // ---- 读取多维表格记录 ----

  /// 读取多维表格全部记录
  /// 返回记录列表，每条记录包含 fields（列名 → 值）
  Future<List<Map<String, dynamic>>> fetchRecords({int pageSize = 500}) async {
    final config = await loadConfig();
    if (config == null) throw FeishuException('飞书配置未完成');

    final token = await _getTenantAccessToken();
    final allRecords = <Map<String, dynamic>>[];
    String? pageToken;

    do {
      final uri = Uri.parse(
        '$_baseUrl/open-apis/bitable/v1/apps/${config.appToken}/tables/${config.tableId}/records',
      ).replace(queryParameters: {
        'page_size': pageSize.toString(),
        if (pageToken != null) 'page_token': pageToken,
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['code'] == 0) {
          final data = body['data'] ?? {};
          final items = data['items'] as List? ?? [];
          for (final item in items) {
            allRecords.add(Map<String, dynamic>.from(item['fields'] ?? {}));
          }
          pageToken = data['has_more'] == true
              ? data['page_token'] as String?
              : null;
        } else {
          throw FeishuException('读取多维表格失败: ${body['msg']}');
        }
      } else {
        throw FeishuException('飞书 API 请求失败: HTTP ${response.statusCode}');
      }
    } while (pageToken != null);

    return allRecords;
  }

  /// 解析飞书多维表格记录为抖音视频指标
  static List<FeishuDouyinMetric> parseDouyinMetrics(
      List<Map<String, dynamic>> records) {
    return records.map((fields) {
      return FeishuDouyinMetric(
        videoTitle:
            _getString(fields, ['视频标题', '标题', 'video_title', 'title']),
        playCount: _getInt(fields, ['播放量', '播放数', 'play_count', 'plays']),
        likeCount: _getInt(fields, ['点赞数', '点赞', 'like_count', 'likes']),
        commentCount:
            _getInt(fields, ['评论数', '评论', 'comment_count', 'comments']),
        shareCount:
            _getInt(fields, ['分享数', '分享', 'share_count', 'shares']),
        collectCount:
            _getInt(fields, ['收藏数', '收藏', 'collect_count', 'collects']),
        publishDate:
            _getString(fields, ['发布时间', '发布日期', 'publish_date', 'date']),
        finishRate: _getDouble(fields, ['完播率', 'finish_rate']),
        avgWatchDuration:
            _getDouble(fields, ['平均观看时长', 'avg_watch_duration']),
      );
    }).toList();
  }

  static String _getString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val != null) return val.toString();
    }
    return '';
  }

  static int _getInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val != null) return int.tryParse(val.toString()) ?? 0;
    }
    return 0;
  }

  static double? _getDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val != null) {
        final str = val.toString().replaceAll('%', '');
        return double.tryParse(str);
      }
    }
    return null;
  }
}

/// 飞书配置
class FeishuConfig {
  final String appId;
  final String appSecret;
  final String appToken;
  final String tableId;

  FeishuConfig({
    required this.appId,
    required this.appSecret,
    required this.appToken,
    required this.tableId,
  });
}

/// 从飞书多维表格解析出的抖音视频指标
class FeishuDouyinMetric {
  final String videoTitle;
  final int playCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int collectCount;
  final String publishDate;
  final double? finishRate;
  final double? avgWatchDuration;
  final double? twoSecondExitRate;
  final double? coverCtr;
  final int profileVisits;
  final int fullPlayCount;
  final double? fiveSecondFinishRate;

  FeishuDouyinMetric({
    required this.videoTitle,
    required this.playCount,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.collectCount,
    required this.publishDate,
    this.finishRate,
    this.avgWatchDuration,
    this.twoSecondExitRate,
    this.coverCtr,
    this.profileVisits = 0,
    this.fullPlayCount = 0,
    this.fiveSecondFinishRate,
  });

  Map<String, dynamic> toJson() => {
        'videoTitle': videoTitle,
        'playCount': playCount,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'shareCount': shareCount,
        'collectCount': collectCount,
        'publishDate': publishDate,
        'finishRate': finishRate,
        'avgWatchDuration': avgWatchDuration,
        'twoSecondExitRate': twoSecondExitRate,
        'coverCtr': coverCtr,
        'profileVisits': profileVisits,
        'fullPlayCount': fullPlayCount,
        'fiveSecondFinishRate': fiveSecondFinishRate,
      };
}

class FeishuException implements Exception {
  final String message;
  FeishuException(this.message);
  @override
  String toString() => 'FeishuException: $message';
}
