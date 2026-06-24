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
            _getString(fields, ['视频标题', '标题', 'video_title', 'title', '作品标题', '作品名称']),
        videoId: _getString(fields, ['视频ID', 'video_id', 'id', 'item_id']),
        playCount: _getInt(fields, ['播放量', '播放数', 'play_count', 'plays', '播放次数']),
        likeCount: _getInt(fields, ['点赞数', '点赞', 'like_count', 'likes', '点赞量']),
        commentCount:
            _getInt(fields, ['评论数', '评论', 'comment_count', 'comments', '评论量']),
        shareCount:
            _getInt(fields, ['分享数', '分享', 'share_count', 'shares', '转发数', '转发量']),
        collectCount:
            _getInt(fields, ['收藏数', '收藏', 'collect_count', 'collects', '收藏量']),
        publishDate:
            _getString(fields, ['发布时间', '发布日期', 'publish_date', 'date', '创建时间', '发布时刻']),
        finishRate: _getDouble(fields, ['完播率', 'finish_rate', '整体完播率']),
        avgWatchDuration:
            _getDouble(fields, ['平均观看时长', 'avg_watch_duration', '均观时长', '人均观看时长', 'AVD']),
        twoSecondExitRate: _getDouble(fields, ['2s跳出率', '2秒跳出率', '两秒跳出率', 'two_second_exit_rate', '2s跳出']),
        fiveSecondFinishRate: _getDouble(fields, ['5s完播率', '5秒完播率', '五秒完播率', 'five_second_finish_rate', '5s完播']),
        coverCtr: _getDouble(fields, ['封面点击率', '点击率', 'CTR', 'cover_ctr', 'ctr', '封面点击']),
        profileVisits: _getInt(fields, ['主页访问量', '主页访问', 'profile_visits', '主页访客', '个人主页访问']),
        fullPlayCount: _getInt(fields, ['完整播放次数', '完整播放', 'full_play_count', '完播数']),
        newFollowers: _getInt(fields, ['新增粉丝', '粉丝增量', '涨粉', '净增粉丝', 'new_followers', '粉丝净增']),
        totalDuration: _getDouble(fields, ['视频时长', '时长', 'duration', '片长']),
        trafficRecommend: _getDouble(fields, ['推荐流量', '推荐流量占比', 'traffic_recommend', '推荐']),
        trafficSearch: _getDouble(fields, ['搜索流量', '搜索流量占比', 'traffic_search', '搜索']),
        trafficFollow: _getDouble(fields, ['关注流量', '关注流量占比', 'traffic_follow', '关注']),
        trafficCity: _getDouble(fields, ['同城流量', '同城流量占比', 'traffic_city', '同城']),
        trafficProfile: _getDouble(fields, ['主页流量', '主页流量占比', 'traffic_profile', '个人主页']),
        trafficHotspot: _getDouble(fields, ['热点流量', '热点流量占比', 'traffic_hotspot', '热点']),
        trafficDoujia: _getDouble(fields, ['DOU+流量', 'DOU+流量占比', 'traffic_doujia', 'Dou+', 'DOU+']),
        audienceMaleRatio: _getDouble(fields, ['男性粉丝占比', '男性占比', 'audience_male_ratio', '男粉占比', '男性比例']),
        audienceFemaleRatio: _getDouble(fields, ['女性粉丝占比', '女性占比', 'audience_female_ratio', '女粉占比', '女性比例']),
        audienceAgeDist: _getJsonStr(fields, ['年龄分布', 'audience_age_dist', '年龄分布数据', '粉丝年龄']),
        audienceRegionDist: _getJsonStr(fields, ['地域分布', 'audience_region_dist', '地域分布数据', '粉丝地域']),
        likeRate: _getDouble(fields, ['点赞率', 'like_rate', '播赞比']),
        commentRate: _getDouble(fields, ['评论率', 'comment_rate', '播评比']),
        shareRate: _getDouble(fields, ['分享率', 'share_rate', '播转率']),
        collectRate: _getDouble(fields, ['收藏率', 'collect_rate', '播藏率']),
        interactionRate: _getDouble(fields, ['互动率', 'interaction_rate', '综合互动率']),
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
        var str = val.toString().replaceAll('%', '');
        final num = double.tryParse(str);
        if (num != null) {
          return val.toString().contains('%') ? num / 100.0 : num;
        }
      }
    }
    return null;
  }

  static String? _getJsonStr(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val != null && val.toString().isNotEmpty) {
        final str = val.toString().trim();
        if (str.startsWith('{') || str.startsWith('[')) return str;
        return str;
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
  final String videoId;
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
  final int newFollowers;
  final double? totalDuration;

  // 流量来源
  final double? trafficRecommend;
  final double? trafficSearch;
  final double? trafficFollow;
  final double? trafficCity;
  final double? trafficProfile;
  final double? trafficHotspot;
  final double? trafficDoujia;

  // 粉丝画像
  final double? audienceMaleRatio;
  final double? audienceFemaleRatio;
  final String? audienceAgeDist;
  final String? audienceRegionDist;

  // 衍生互动率
  final double? likeRate;
  final double? commentRate;
  final double? shareRate;
  final double? collectRate;
  final double? interactionRate;

  FeishuDouyinMetric({
    this.videoId = '',
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
    this.newFollowers = 0,
    this.totalDuration,
    this.trafficRecommend,
    this.trafficSearch,
    this.trafficFollow,
    this.trafficCity,
    this.trafficProfile,
    this.trafficHotspot,
    this.trafficDoujia,
    this.audienceMaleRatio,
    this.audienceFemaleRatio,
    this.audienceAgeDist,
    this.audienceRegionDist,
    this.likeRate,
    this.commentRate,
    this.shareRate,
    this.collectRate,
    this.interactionRate,
  });

  Map<String, dynamic> toJson() => {
        'video_id': videoId,
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
        'newFollowers': newFollowers,
        'totalDuration': totalDuration,
        'trafficRecommend': trafficRecommend,
        'trafficSearch': trafficSearch,
        'trafficFollow': trafficFollow,
        'trafficCity': trafficCity,
        'trafficProfile': trafficProfile,
        'trafficHotspot': trafficHotspot,
        'trafficDoujia': trafficDoujia,
        'audienceMaleRatio': audienceMaleRatio,
        'audienceFemaleRatio': audienceFemaleRatio,
        'audienceAgeDist': audienceAgeDist,
        'audienceRegionDist': audienceRegionDist,
        'likeRate': likeRate,
        'commentRate': commentRate,
        'shareRate': shareRate,
        'collectRate': collectRate,
        'interactionRate': interactionRate,
      };
}

class FeishuException implements Exception {
  final String message;
  FeishuException(this.message);
  @override
  String toString() => 'FeishuException: $message';
}
