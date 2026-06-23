import 'package:csv/csv.dart';
import 'dart:io';

/// CSV 解析器 - 处理抖音创作者后台导出的 CSV
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
           row['video_id'] ??
           row['item_id'] ??
           row['作品ID'];
  }

  /// 从 CSV 行提取深度指标
  Map<String, dynamic> extractDeepMetrics(Map<String, String> row) {
    return {
      if (row['完播率'] != null)
        'finish_rate': double.tryParse(row['完播率']!.replaceAll('%', '')),
      if (row['平均观看时长'] != null)
        'avg_watch_duration': double.tryParse(row['平均观看时长']!),
      if (row['推荐流占比'] != null || row['推荐feed'] != null)
        'traffic_recommend': double.tryParse(
          (row['推荐流占比'] ?? row['推荐feed'] ?? '').replaceAll('%', ''),
        ),
      if (row['搜索占比'] != null)
        'traffic_search': double.tryParse(row['搜索占比']!.replaceAll('%', '')),
      if (row['关注占比'] != null)
        'traffic_follow': double.tryParse(row['关注占比']!.replaceAll('%', '')),
      if (row['同城占比'] != null)
        'traffic_city': double.tryParse(row['同城占比']!.replaceAll('%', '')),
      if (row['男性占比'] != null)
        'audience_male_ratio': double.tryParse(row['男性占比']!.replaceAll('%', '')),
      if (row['年龄分布'] != null)
        'audience_age_dist': row['年龄分布'],
      if (row['地域分布'] != null)
        'audience_region_dist': row['地域分布'],
      if (row['TGI'] != null)
        'audience_tgi': row['TGI'],
    };
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
