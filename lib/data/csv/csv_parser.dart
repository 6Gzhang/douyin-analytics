import 'package:csv/csv.dart';
import 'dart:io';

/// CSV 解析器 - 处理抖音创作者后台导出的 CSV
/// 字段名称兼容抖音创作者后台和飞书数据看板的各种命名
class CsvParser {
  /// 解析 CSV 文件，返回 Map 列表
  Future<List<Map<String, String>>> parse(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(content);

    if (rows.isEmpty) return [];

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final dataRows = rows.skip(1).toList();

    return dataRows.map((row) {
      final map = <String, String>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        map[headers[i]] = row[i].toString().trim();
      }
      return map;
    }).toList();
  }

  /// 从 CSV 行提取视频 ID
  String? extractVideoId(Map<String, String> row) {
    // 抖音创作者后台 CSV 中视频 ID 可能在不同列名中
    return row['视频ID'] ??
           row['id'] ??
           row['item_id'] ??
           row['作品ID'] ??
           row['itemid'] ??
           row['ID'] ??
           row['video_id'] ??
           row['Video ID'];
  }

  /// 从 CSV 行提取标题
  String? extractTitle(Map<String, String> row) {
    return row['视频标题'] ??
           row['标题'] ??
           row['title'] ??
           row['作品标题'] ??
           row['作品名称'] ??
           row['video_title'] ??
           row['内容标题'];
  }

  /// 从 CSV 行提取发布时间
  String? extractPublishDate(Map<String, String> row) {
    return row['发布时间'] ??
           row['发布日期'] ??
           row['date'] ??
           row['创建时间'] ??
           row['发布时刻'] ??
           row['上传时间'] ??
           row['publish_date'] ??
           row['创建日期'];
  }

  /// 从 CSV 行提取深度指标
  /// 完整字段映射表
  Map<String, dynamic> extractDeepMetrics(Map<String, String> row) {
    return {
      // ===== 基础数据 =====
      if (_hasValue(row, '播放量', '播放数', 'play_count', 'plays', '播放次数', '总播放量'))
        'play_count': _parseInt(row, '播放量', '播放数', 'play_count', 'plays', '播放次数', '总播放量'),
      if (_hasValue(row, '点赞数', '点赞', 'like_count', 'likes', '点赞量', '总点赞'))
        'like_count': _parseInt(row, '点赞数', '点赞', 'like_count', 'likes', '点赞量', '总点赞'),
      if (_hasValue(row, '评论数', '评论', 'comment_count', 'comments', '评论量', '总评论'))
        'comment_count': _parseInt(row, '评论数', '评论', 'comment_count', 'comments', '评论量', '总评论'),
      if (_hasValue(row, '分享数', '分享', 'share_count', 'shares', '转发数', '转发量', '总分享'))
        'share_count': _parseInt(row, '分享数', '分享', 'share_count', 'shares', '转发数', '转发量', '总分享'),
      if (_hasValue(row, '收藏数', '收藏', 'collect_count', 'collects', '收藏量', '总收藏'))
        'collect_count': _parseInt(row, '收藏数', '收藏', 'collect_count', 'collects', '收藏量', '总收藏'),

      // ===== 深度数据 - 完播相关 =====
      if (_hasValue(row, '完播率', 'finish_rate', '整体完播率', '完播', '视频完播率'))
        'finish_rate': _parsePercent(row, '完播率', 'finish_rate', '整体完播率', '完播', '视频完播率'),
      if (_hasValue(row, '平均观看时长', 'avg_watch_duration', '均观时长', '人均观看时长', 'AVD'))
        'avg_watch_duration': _parseDouble(row, '平均观看时长', 'avg_watch_duration', '均观时长', '人均观看时长', 'AVD'),
      if (_hasValue(row, '2s跳出率', '2秒跳出率', '两秒跳出率', 'two_second_exit_rate', '2s跳出', '跳出率'))
        'two_second_exit_rate': _parsePercent(row, '2s跳出率', '2秒跳出率', '两秒跳出率', 'two_second_exit_rate', '2s跳出', '跳出率'),
      if (_hasValue(row, '5s完播率', '5秒完播率', '五秒完播率', 'five_second_finish_rate', '5s完播', '5秒完成率'))
        'five_second_finish_rate': _parsePercent(row, '5s完播率', '5秒完播率', '五秒完播率', 'five_second_finish_rate', '5s完播', '5秒完成率'),
      if (_hasValue(row, '完整播放次数', '完整播放', 'full_play_count', '完播数', '完播次数'))
        'full_play_count': _parseInt(row, '完整播放次数', '完整播放', 'full_play_count', '完播数', '完播次数', '总完播人数'),

      // ===== 封面与主页 =====
      if (_hasValue(row, '封面点击率', '点击率', 'CTR', 'cover_ctr', 'ctr'))
        'cover_ctr': _parsePercent(row, '封面点击率', '点击率', 'CTR', 'cover_ctr', 'ctr'),
      if (_hasValue(row, '主页访问量', '主页访问', 'profile_visits', '主页访客', '个人主页访问'))
        'profile_visits': _parseInt(row, '主页访问量', '主页访问', 'profile_visits', '主页访客', '个人主页访问'),

      // ===== 粉丝相关 =====
      if (_hasValue(row, '新增粉丝', '粉丝增量', '涨粉', '净增粉丝', 'new_followers', '粉丝净增'))
        'new_followers': _parseInt(row, '新增粉丝', '粉丝增量', '涨粉', '净增粉丝', 'new_followers', '粉丝净增'),

      // ===== 视频属性 =====
      if (_hasValue(row, '视频时长', '时长', 'duration', '片长'))
        'total_duration': _parseDouble(row, '视频时长', '时长', 'duration', '片长'),

      // ===== 流量来源 =====
      if (_hasValue(row, '推荐流量', '推荐流量占比', 'traffic_recommend', '推荐', '推荐占比', '推荐流占比'))
        'traffic_recommend': _parsePercent(row, '推荐流量', '推荐流量占比', 'traffic_recommend', '推荐', '推荐占比', '推荐流占比'),
      if (_hasValue(row, '搜索流量', '搜索流量占比', 'traffic_search', '搜索', '搜索占比', '搜索流占比'))
        'traffic_search': _parsePercent(row, '搜索流量', '搜索流量占比', 'traffic_search', '搜索', '搜索占比', '搜索流占比'),
      if (_hasValue(row, '关注流量', '关注流量占比', 'traffic_follow', '关注', '关注占比', '关注流占比'))
        'traffic_follow': _parsePercent(row, '关注流量', '关注流量占比', 'traffic_follow', '关注', '关注占比', '关注流占比'),
      if (_hasValue(row, '同城流量', '同城流量占比', 'traffic_city', '同城', '同城占比', '同城流占比'))
        'traffic_city': _parsePercent(row, '同城流量', '同城流量占比', 'traffic_city', '同城', '同城占比', '同城流占比'),
      if (_hasValue(row, '主页流量', '主页流量占比', 'traffic_profile', '个人主页'))
        'traffic_profile': _parsePercent(row, '主页流量', '主页流量占比', 'traffic_profile', '个人主页'),
      if (_hasValue(row, '热点流量', '热点流量占比', 'traffic_hotspot', '热点'))
        'traffic_hotspot': _parsePercent(row, '热点流量', '热点流量占比', 'traffic_hotspot', '热点'),
      if (_hasValue(row, 'DOU+流量', 'DOU+流量占比', 'traffic_doujia', 'Dou+', 'DOU+'))
        'traffic_doujia': _parsePercent(row, 'DOU+流量', 'DOU+流量占比', 'traffic_doujia', 'Dou+', 'DOU+'),

      // ===== 粉丝画像 =====
      if (_hasValue(row, '男性粉丝占比', '男性占比', 'audience_male_ratio', '男粉占比', '男性比例'))
        'audience_male_ratio': _parsePercent(row, '男性粉丝占比', '男性占比', 'audience_male_ratio', '男粉占比', '男性比例'),
      if (_hasValue(row, '女性粉丝占比', '女性占比', 'audience_female_ratio', '女粉占比', '女性比例'))
        'audience_female_ratio': _parsePercent(row, '女性粉丝占比', '女性占比', 'audience_female_ratio', '女粉占比', '女性比例'),
      if (_hasValue(row, '年龄分布', 'audience_age_dist', '年龄分布数据', '粉丝年龄'))
        'audience_age_dist': _getString(row, '年龄分布', 'audience_age_dist', '年龄分布数据', '粉丝年龄'),
      if (_hasValue(row, '地域分布', 'audience_region_dist', '地域分布数据', '粉丝地域'))
        'audience_region_dist': _getString(row, '地域分布', 'audience_region_dist', '地域分布数据', '粉丝地域'),
      if (_hasValue(row, 'TGI'))
        'audience_tgi': _getString(row, 'TGI'),

      // ===== 互动比率 =====
      if (_hasValue(row, '点赞率', 'like_rate', '播赞比', '点赞占比'))
        'like_rate': _parsePercent(row, '点赞率', 'like_rate', '播赞比', '点赞占比'),
      if (_hasValue(row, '评论率', 'comment_rate', '播评比', '评论占比'))
        'comment_rate': _parsePercent(row, '评论率', 'comment_rate', '播评比', '评论占比'),
      if (_hasValue(row, '分享率', 'share_rate', '播转比', '分享占比'))
        'share_rate': _parsePercent(row, '分享率', 'share_rate', '播转比', '分享占比'),
      if (_hasValue(row, '收藏率', 'collect_rate', '播藏比', '收藏占比'))
        'collect_rate': _parsePercent(row, '收藏率', 'collect_rate', '播藏比', '收藏占比'),
      if (_hasValue(row, '互动率', 'interaction_rate', '综合互动率', '总互动率'))
        'interaction_rate': _parsePercent(row, '互动率', 'interaction_rate', '综合互动率', '总互动率'),
    };
  }

  /// 检查是否存在任意一个指定的键
  bool _hasValue(Map<String, String> row, String key1, [String? key2, String? key3, String? key4, String? key5, String? key6, String? key7]) {
    final keys = [key1, key2, key3, key4, key5, key6, key7].whereType<String>().toList();
    for (final key in keys) {
      final val = row[key];
      if (val != null && val.isNotEmpty) return true;
    }
    return false;
  }

  /// 获取字符串值
  String? _getString(Map<String, String> row, String key1, [String? key2, String? key3, String? key4, String? key5, String? key6, String? key7, String? key8]) {
    for (final key in [key1, key2, key3, key4, key5, key6, key7, key8]) {
      if (key != null) {
        final val = row[key];
        if (val != null && val.isNotEmpty) return val;
      }
    }
    return null;
  }

  /// 解析整数
  int _parseInt(Map<String, String> row, String key1, [String? key2, String? key3, String? key4, String? key5, String? key6, String? key7]) {
    final val = _getString(row, key1, key2, key3, key4, key5, key6, key7);
    if (val == null) return 0;
    // 清理可能的逗号（如 1,234,567）
    final cleaned = val.replaceAll(',', '').replaceAll('，', '');
    return int.tryParse(cleaned) ?? 0;
  }

  /// 解析浮点数
  double? _parseDouble(Map<String, String> row, String key1, [String? key2, String? key3, String? key4, String? key5]) {
    final val = _getString(row, key1, key2, key3, key4, key5);
    if (val == null) return null;
    final cleaned = val.replaceAll(',', '').replaceAll('，', '').replaceAll('%', '');
    return double.tryParse(cleaned);
  }

  /// 解析百分比（自动处理 % 符号）
  double? _parsePercent(Map<String, String> row, String key1, [String? key2, String? key3, String? key4, String? key5, String? key6, String? key7]) {
    final val = _getString(row, key1, key2, key3, key4, key5, key6, key7);
    if (val == null) return null;
    final cleaned = val.replaceAll(',', '').replaceAll('，', '').replaceAll('%', '');
    final num = double.tryParse(cleaned);
    if (num == null) return null;
    // 如果原值包含 % 符号，则转换为小数
    return val.contains('%') ? num / 100.0 : num;
  }
}

/// CSV 数据匹配器 - 将 CSV 数据匹配到已有视频
class CsvMatcher {
  final CsvParser _parser = CsvParser();

  /// 匹配并返回结构化结果
  Future<CsvMatchResult> match(String filePath) async {
    final rows = await _parser.parse(filePath);
    final matched = <VideoMatchRecord>[];
    final unmatched = <Map<String, String>>[];

    for (final row in rows) {
      final videoId = _parser.extractVideoId(row);
      final metrics = _parser.extractDeepMetrics(row);

      if (videoId != null && videoId.isNotEmpty && metrics.isNotEmpty) {
        matched.add(VideoMatchRecord(videoId: videoId, metrics: metrics));
      } else {
        unmatched.add(row);
      }
    }

    return CsvMatchResult(matched: matched, unmatched: unmatched);
  }
}

class VideoMatchRecord {
  final String videoId;
  final Map<String, dynamic> metrics;

  VideoMatchRecord({required this.videoId, required this.metrics});
}

class CsvMatchResult {
  final List<VideoMatchRecord> matched;
  final List<Map<String, String>> unmatched;

  CsvMatchResult({required this.matched, required this.unmatched});
}
