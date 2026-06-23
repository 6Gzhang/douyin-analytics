import 'package:shared_preferences/shared_preferences.dart';

/// Smart API Adapter - auto-adapts CSV field mapping
class ApiAdapter {
  ApiAdapter._();
  static final ApiAdapter instance = ApiAdapter._();

  /// Built-in field alias knowledge base (latest Douyin CSV)
  static const Map<String, List<String>> fieldAliases = {
    '播放量': ['播放量', '播放', '观看量', '播放数', '浏览量', 'vv', 'VV'],
    '完播率': ['完播率', '完整观看率', '完播'],
    '点赞数': ['点赞量', '点赞数', '点赞', '赞', 'digg_count'],
    '评论数': ['评论量', '评论数', '评论', 'comment_count'],
    '分享数': ['分享量', '分享数', '分享', '转发量', '转发数', '转发', 'share_count'],
    '收藏数': ['收藏量', '收藏数', '收藏', 'collect_count'],
    '新增粉丝': ['粉丝增量', '新增粉丝', '涨粉', '净增粉丝', 'fans_increment'],
    '视频标题': ['作品名称', '作品标题', '视频标题', '标题', 'title', 'desc'],
    '发布时间': ['发布时间', '发布日期', '创建时间', '时间', 'create_time', 'publish_time'],
    '2秒跳出率': ['2s跳出率', '2秒跳出率', '两秒跳出率'],
    '封面点击率': ['封面点击率', '点击率', 'CTR', 'ctr'],
    '主页访问量': ['主页访问量', '主页访问', 'profile_visits'],
    '完整播放次数': ['完整播放次数', '完整播放', 'full_play_count'],
    '5秒完播率': ['5s完播率', '5秒完播率', '五秒完播率'],
    '平均观看时长': [
      '平均观看时长',
      '均观时长',
      'avg_watch_time',
      'AVD'
    ],
  };

  static const _mappingPrefix = 'field_map_';

  /// Load field mapping from SharedPreferences
  Future<Map<String, String>> loadFieldMapping() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_mappingPrefix));
    final mapping = <String, String>{};
    for (final key in keys) {
      final val = prefs.getString(key);
      if (val != null && val.isNotEmpty) {
        mapping[key.substring(_mappingPrefix.length)] = val;
      }
    }
    return mapping;
  }

  /// Persist a single field mapping
  Future<void> saveFieldMapping(Map<String, String> mapping) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in mapping.entries) {
      await prefs.setString('$_mappingPrefix${entry.key}', entry.value);
    }
  }

  /// Detect unknown new fields in CSV headers
  List<String> detectNewFields(
      List<String> csvHeaders, Map<String, String> knownMapping) {
    final unknown = <String>[];
    for (final header in csvHeaders) {
      final h = header.trim();
      // Check if already mapped
      if (knownMapping.containsKey(h) || knownMapping.containsValue(h)) {
        continue;
      }
      // Check if matches any alias in fieldAliases
      bool found = false;
      for (final aliases in fieldAliases.values) {
        if (aliases.contains(h)) {
          found = true;
          break;
        }
      }
      if (!found) unknown.add(h);
    }
    return unknown;
  }

  /// Auto-suggest mapping for unknown fields based on alias knowledge base
  Map<String, String> suggestMapping(List<String> unknownFields) {
    final suggestions = <String, String>{};
    for (final field in unknownFields) {
      for (final entry in fieldAliases.entries) {
        final standardName = entry.key;
        final aliases = entry.value;
        // Fuzzy match: contains or case-insensitive
        final lower = field.toLowerCase();
        for (final alias in aliases) {
          if (alias.toLowerCase() == lower ||
              lower.contains(alias.toLowerCase()) ||
              alias.toLowerCase().contains(lower)) {
            suggestions[field] = standardName;
            break;
          }
        }
        if (suggestions.containsKey(field)) break;
      }
    }
    return suggestions;
  }

  /// Validate parsed data row for reasonableness
  String? validateParsedData(Map<String, dynamic> row) {
    final playCount = (row['play_count'] as int?) ?? 0;
    final likeCount = (row['like_count'] as int?) ?? 0;
    final commentCount = (row['comment_count'] as int?) ?? 0;
    final shareCount = (row['share_count'] as int?) ?? 0;
    final collectCount = (row['collect_count'] as int?) ?? 0;

    // Negative values
    if (playCount < 0 || likeCount < 0 || commentCount < 0 ||
        shareCount < 0 || collectCount < 0) {
      return '包含负数指标（播放/点赞/评论/分享/收藏）';
    }
    // Like count exceeds play count (suspicious)
    if (likeCount > 0 && playCount > 0 && likeCount > playCount * 2) {
      return '点赞数($likeCount)远大于播放量($playCount)的2倍，数据异常';
    }
    return null; // valid
  }

  /// Log adaptation record (stub)
  void logAdaptation(String field, String from, String to) {
    // Best effort logging stub
  }
}
