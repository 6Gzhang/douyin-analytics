import 'package:flutter/foundation.dart';
import 'feishu_service.dart';

/// CSV 解析器 - 解析抖音数据导出格式
/// 字段名称兼容抖音创作者后台和飞书数据看板的各种命名
class CsvParser {
  CsvParser._();

  /// 解析抖音数据 CSV（基础版，兼容旧调用）
  static List<FeishuDouyinMetric> parseDouyinData(
    List<List<dynamic>> rows,
  ) {
    if (rows.isEmpty) return [];
    final header = rows.first.map((e) => e.toString().trim()).toList();
    final results = <FeishuDouyinMetric>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      final map = <String, String>{};
      for (int j = 0; j < header.length && j < row.length; j++) {
        map[header[j]] = (row[j] ?? '').toString().trim();
      }
      results.add(FeishuDouyinMetric(
        // ===== 基础信息 =====
        videoTitle: _get(map, [
          '视频标题', '标题', 'title', 'video_title', '作品标题', '作品名称', '内容标题',
        ]),
        videoId: _get(map, [
          '视频ID', 'id', 'item_id', '作品ID', 'ID', 'video_id', 'Video ID', 'itemid',
        ]),
        publishDate: _get(map, [
          '发布时间', '发布日期', 'date', '创建时间', '发布时刻', '上传时间',
          'publish_date', '创建日期', '发布时间(毫秒)',
        ]),

        // ===== 互动数据 =====
        playCount: _getInt(map, [
          '播放量', '播放数', 'plays', '播放次数', '总播放量', 'play_count',
          '视频播放量', '播放 (w)',
        ]),
        likeCount: _getInt(map, [
          '点赞数', '点赞', 'likes', '点赞量', '总点赞', 'like_count',
          '点赞 (w)', '获赞数',
        ]),
        commentCount: _getInt(map, [
          '评论数', '评论', 'comments', '评论量', '总评论', 'comment_count',
          '评论 (w)',
        ]),
        shareCount: _getInt(map, [
          '分享数', '分享', 'shares', '转发数', '转发量', '总分享', 'share_count',
          '分享 (w)',
        ]),
        collectCount: _getInt(map, [
          '收藏数', '收藏', 'collects', '收藏量', '总收藏', 'collect_count',
          '收藏 (w)',
        ]),

        // ===== 深度数据 - 完播相关 =====
        finishRate: _getDouble(map, [
          '完播率', 'finish_rate', '整体完播率', '完播', '视频完播率',
          '完播率 (%)', '完播率(%)', 'complete_rate', '视频完播率(%)',
          '平均完播率', '完播率（整体）',
        ]),
        avgWatchDuration: _getDouble(map, [
          '平均观看时长', 'avg_watch_duration', '均观时长', '人均观看时长', 'AVD',
          '平均播放时长', '平均播放时长(秒)', '视频平均播放时长',
          '观看时长(秒)', '播放时长', '人均播放时长(秒)',
        ]),
        twoSecondExitRate: _getDouble(map, [
          '2s跳出率', '2秒跳出率', '两秒跳出率', 'two_second_exit_rate',
          '2s跳出', '跳出率', '2秒跳出', '两秒跳出率(%)',
          '跳出率(%)', '2s跳出率(%)',
        ]),
        fiveSecondFinishRate: _getDouble(map, [
          '5s完播率', '5秒完播率', '五秒完播率', 'five_second_finish_rate',
          '5s完播', '5秒完成率', '5s完成率',
          '5s完播率(%)', '5秒完播率(%)',
        ]),
        fullPlayCount: _getInt(map, [
          '完整播放次数', '完整播放', 'full_play_count', '完播数',
          '完播次数', '视频完播次数', '完整播放人数', '总完播人数',
        ]),

        // ===== 封面与主页 =====
        coverCtr: _getDouble(map, [
          '封面点击率', '点击率', 'CTR', 'cover_ctr', 'ctr',
          '封面点击', '封面点击率(%)', '点击率(%)',
          '曝光-点击率',
        ]),
        profileVisits: _getInt(map, [
          '主页访问量', '主页访问', 'profile_visits', '主页访客',
          '个人主页访问', '主页浏览量', '个人主页访问量', '主页访问人数', '浏览量',
        ]),

        // ===== 粉丝相关 =====
        newFollowers: _getInt(map, [
          '新增粉丝', '粉丝增量', '涨粉', '净增粉丝', 'new_followers',
          '粉丝净增', '新增关注', '涨粉数', '新增关注数', '粉丝增长',
        ]),

        // ===== 视频属性 =====
        totalDuration: _getDouble(map, [
          '视频时长', '时长', 'duration', '片长',
          '视频时长(秒)', '秒',
        ]),

        // ===== 流量来源 =====
        trafficRecommend: _getDouble(map, [
          '推荐流量', '推荐流量占比', 'traffic_recommend', '推荐',
          '推荐占比', '推荐流量(%)', '推荐流占比',
          '推荐来源占比',
        ]),
        trafficSearch: _getDouble(map, [
          '搜索流量', '搜索流量占比', 'traffic_search', '搜索',
          '搜索占比', '搜索流量(%)', '搜索流占比',
          '搜索来源占比',
        ]),
        trafficFollow: _getDouble(map, [
          '关注流量', '关注流量占比', 'traffic_follow', '关注',
          '关注占比', '关注流量(%)', '关注流占比',
          '粉丝来源占比',
        ]),
        trafficCity: _getDouble(map, [
          '同城流量', '同城流量占比', 'traffic_city', '同城',
          '同城占比', '同城流量(%)', '同城流占比',
          '同城来源占比',
        ]),
        trafficProfile: _getDouble(map, [
          '主页流量', '主页流量占比', 'traffic_profile', '个人主页',
          'profile', '主页访问', '个人主页流量占比',
        ]),
        trafficHotspot: _getDouble(map, [
          '热点流量', '热点流量占比', 'traffic_hotspot', '热点',
          '热点来源', '热点占比',
          '热门来源占比',
        ]),
        trafficDoujia: _getDouble(map, [
          'DOU+流量', 'DOU+流量占比', 'traffic_doujia', 'Dou+', 'DOU+',
          'DOU+来源', 'DOU+占比',
          '付费推广流量',
        ]),

        // ===== 粉丝画像 =====
        audienceMaleRatio: _getDouble(map, [
          '男性粉丝占比', '男性占比', 'audience_male_ratio', '男粉占比',
          '男性比例', '男性', '粉丝男性占比',
          'Male Ratio', '男性粉丝比例 (%)',
        ]),
        audienceFemaleRatio: _getDouble(map, [
          '女性粉丝占比', '女性占比', 'audience_female_ratio', '女粉占比',
          '女性比例', '女性', '粉丝女性占比',
          'Female Ratio', '女性粉丝比例 (%)',
        ]),
        audienceAgeDist: _getJsonStr(map, [
          '年龄分布', 'audience_age_dist', '年龄分布数据', '粉丝年龄',
          '粉丝年龄分布', '观众年龄分布',
          '粉丝年龄占比',
        ]),
        audienceRegionDist: _getJsonStr(map, [
          '地域分布', 'audience_region_dist', '地域分布数据', '粉丝地域',
          '粉丝地域分布', '观众地域分布',
          '粉丝地域占比',
        ]),

        // ===== 互动比率 =====
        likeRate: _getDouble(map, [
          '点赞率', 'like_rate', '播赞比', '点赞占比',
          '点赞/播放 (%)', '点赞率(%)',
        ]),
        commentRate: _getDouble(map, [
          '评论率', 'comment_rate', '播评比', '评论占比',
          '评论/播放 (%)', '评论率(%)',
        ]),
        shareRate: _getDouble(map, [
          '分享率', 'share_rate', '播转比', '分享占比',
          '分享/播放 (%)', '分享率(%)',
        ]),
        collectRate: _getDouble(map, [
          '收藏率', 'collect_rate', '播藏比', '收藏占比',
          '收藏/播放 (%)', '收藏率(%)',
        ]),
        interactionRate: _getDouble(map, [
          '互动率', 'interaction_rate', '综合互动率', '总互动率',
          '互动/播放 (%)', '互动率(%)',
          '总互动占比', '整体互动率',
        ]),
      ));
    }
    return results;
  }

  /// 增强解析 - 返回包含所有新字段的 Map 列表
  /// [customFieldMapping] 可选，key=标准字段名，value=CSV表头名
  static List<Map<String, dynamic>> parseDouyinDataEnhanced(
    List<List<dynamic>> rows, {
    Map<String, String>? customFieldMapping,
  }) {
    if (rows.isEmpty) return [];
    final header = rows.first.map((e) => e.toString().trim()).toList();
    final results = <Map<String, dynamic>>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      final map = <String, String>{};
      for (int j = 0; j < header.length && j < row.length; j++) {
        map[header[j]] = (row[j] ?? '').toString().trim();
      }
      // 应用自定义映射
      if (customFieldMapping != null && customFieldMapping.isNotEmpty) {
        final remapped = <String, String>{};
        for (final entry in customFieldMapping.entries) {
          if (map.containsKey(entry.value)) {
            remapped[entry.key] = map[entry.value]!;
          } else if (map.containsKey(entry.key)) {
            remapped[entry.key] = map[entry.key]!;
          }
        }
        for (final entry in map.entries) {
          remapped.putIfAbsent(entry.key, () => entry.value);
        }
        map.clear();
        map.addAll(remapped);
      }
      results.add({
        'title': _get(map, ['视频标题', '标题', 'video_title', 'title', '作品名称']),
        'play_count': _getInt(map, ['播放量', '播放数', 'play_count', 'plays']),
        'like_count': _getInt(map, ['点赞数', '点赞', 'like_count', 'likes', '点赞量']),
        'comment_count': _getInt(map, ['评论数', '评论', 'comment_count', 'comments', '评论量']),
        'share_count': _getInt(map, ['分享数', '分享', 'share_count', 'shares', '转发数', '转发量']),
        'collect_count': _getInt(map, ['收藏数', '收藏', 'collect_count', 'collects', '收藏量']),
        'create_time': _getTimestamp(map, ['发布时间', '发布日期', 'publish_date', 'create_time', '时间']),
        'finish_rate': _getDouble(map, ['完播率', 'finish_rate']),
        'avg_watch_duration': _getDouble(map, ['平均观看时长', 'avg_watch_duration', '均观时长', 'AVD']),
        'two_second_exit_rate': _getDouble(map, ['2s跳出率', '2秒跳出率', '两秒跳出率', 'two_second_exit_rate']),
        'cover_ctr': _getDouble(map, ['封面点击率', '点击率', 'CTR', 'cover_ctr', 'ctr']),
        'profile_visits': _getInt(map, ['主页访问量', '主页访问', 'profile_visits']),
        'full_play_count': _getInt(map, ['完整播放次数', '完整播放', 'full_play_count']),
        'five_second_finish_rate': _getDouble(map, ['5s完播率', '5秒完播率', '五秒完播率']),
        'new_followers': _getInt(map, ['新增粉丝', '粉丝增量', '涨粉', '净增粉丝']),
      });
    }
    return results;
  }

  static String _get(Map<String, String> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val != null && val.isNotEmpty) return val;
    }
    return '';
  }

  static int _getInt(Map<String, String> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val != null && val.isNotEmpty) {
        if (val == '-' || val.toUpperCase() == 'N/A' || val == '--') return 0;
        final cleaned = val.replaceAll(',', '');
        return int.tryParse(cleaned) ?? 0;
      }
    }
    return 0;
  }

  static double? _getDouble(Map<String, String> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val != null && val.isNotEmpty) {
        if (val == '-' || val.toUpperCase() == 'N/A' || val == '--') return null;
        var cleaned = val.replaceAll(',', '');
        final isPercent = cleaned.endsWith('%');
        if (isPercent) cleaned = cleaned.substring(0, cleaned.length - 1);
        final num = double.tryParse(cleaned);
        if (num != null) return isPercent ? num / 100.0 : num;
      }
    }
    return null;
  }

  static String? _getJsonStr(Map<String, String> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val != null && val.isNotEmpty) {
        final str = val.trim();
        if (str.startsWith('{') || str.startsWith('[')) return str;
        return str;
      }
    }
    return null;
  }

  static int _getTimestamp(Map<String, String> map, List<String> keys) {
    final val = _get(map, keys);
    if (val.isEmpty) return 0;
    final numVal = int.tryParse(val);
    if (numVal != null) {
      if (numVal > 1e12) return numVal;
      if (numVal > 1e9) return numVal * 1000;
      return numVal;
    }
    try {
      final dt = DateTime.tryParse(val);
      if (dt != null) return dt.millisecondsSinceEpoch;
    } catch (e) {
      debugPrint('解析日期失败: $val, 错误: $e');
    }
    return 0;
  }
}
