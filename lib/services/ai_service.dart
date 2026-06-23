import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static const String _endpoint =
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  static const String _defaultModel = 'qwen-plus';

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('dashscope_api_key');
  }

  Future<String> _getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('dashscope_model') ?? _defaultModel;
  }

  /// Update API key (called from settings page)
  Future<void> updateApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashscope_api_key', key);
  }

  /// Set model (called from settings page)
  Future<void> setModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashscope_model', model);
  }

  /// Increase AI usage counter
  Future<void> _incrementUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('ai_usage_count') ?? 0;
    await prefs.setInt('ai_usage_count', count + 1);
  }

  /// Estimate tokens (rough: ~3 chars per token for Chinese)
  Future<void> _addTokenEstimate(String content) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getInt('ai_estimated_tokens') ?? 0;
    await prefs.setInt('ai_estimated_tokens', existing + (content.length ~/ 3));
  }

  /// Single-turn chat
  Future<String> chat(String systemPrompt, String userMessage) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return '请先在设置页配置阿里云百炼 API Key（免费注册送 100 万 Tokens）。';
    }
    final model = await _getModel();

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final content =
            body['choices']?[0]?['message']?['content'] as String? ?? '';
        await _incrementUsage();
        await _addTokenEstimate(systemPrompt + userMessage + content);
        return content;
      } else {
        final body = jsonDecode(response.body);
        final msg = body['error']?['message'] as String? ??
            body['message'] as String? ??
            'HTTP ${response.statusCode}';
        if (response.statusCode == 401 || response.statusCode == 403) {
          return 'API Key 无效或已过期，请在设置页更新阿里云百炼 API Key。';
        }
        if (msg.contains('quota') || msg.contains('insufficient')) {
          return 'API 额度已耗尽，请前往阿里云百炼控制台查看用量。';
        }
        return 'AI 服务请求失败: $msg';
      }
    } on http.ClientException {
      return '网络连接失败，请检查网络后重试。';
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return '请求超时，AI 服务响应较慢，请稍后重试。';
      }
      return 'AI 服务异常: $e';
    }
  }

  /// Analyze single video
  Future<String> analyzeVideo(
      String title, Map<String, dynamic> metrics) async {
    final sb = StringBuffer();
    sb.writeln('请作为资深抖音运营分析师，深度分析这条视频：');
    sb.writeln('标题：$title');
    sb.writeln('播放量：${metrics['play_count'] ?? 0}');
    sb.writeln('点赞数：${metrics['like_count'] ?? 0}');
    sb.writeln('评论数：${metrics['comment_count'] ?? 0}');
    sb.writeln('分享数：${metrics['share_count'] ?? 0}');
    sb.writeln('收藏数：${metrics['collect_count'] ?? 0}');
    sb.writeln('完播率：${((metrics['finish_rate'] as double?) ?? 0).toStringAsFixed(1)}%');
    sb.writeln(
        '平均观看时长：${((metrics['avg_watch_duration'] as double?) ?? 0).toStringAsFixed(1)}s');
    final tsr = (metrics['two_second_exit_rate'] as double?) ?? 0;
    if (tsr > 0) sb.writeln('2秒跳出率：${tsr.toStringAsFixed(1)}%');
    final ctr = (metrics['cover_ctr'] as double?) ?? 0;
    if (ctr > 0) sb.writeln('封面点击率：${ctr.toStringAsFixed(1)}%');

    sb.writeln();
    sb.writeln('请按以下格式输出分析：');
    sb.writeln('一、核心亮点（1条）');
    sb.writeln('二、主要问题（2-3条，每条标注对应数据）');
    sb.writeln('三、优化建议（3条，按优先级排序，每条具体可执行）');
    sb.writeln('回答要简洁专业，控制在200字以内。');

    return chat(
      '你是拥有5年抖音运营经验的资深分析师，擅长从数据中发现问题并给出可落地的优化建议。懂完播率、互动率、流量层级等抖音算法逻辑。回答简洁有力，用数据说话。',
      sb.toString(),
    );
  }

  /// Suggest titles based on top videos
  Future<String> suggestTitles(List<Map<String, dynamic>> topVideos) async {
    final sb = StringBuffer();
    sb.writeln('以下是我表现最好的几条视频：');
    for (int i = 0; i < topVideos.length && i < 5; i++) {
      final v = topVideos[i];
      sb.writeln(
          '${i + 1}. 《${v['title'] ?? '无标题'}》播放量：${v['plays'] ?? 0}，互动率：${v['interaction_rate']?.toStringAsFixed(1) ?? '--'}%');
    }
    sb.writeln();
    sb.writeln('请基于这些高播放视频的风格，为我推荐：');
    sb.writeln('1. 3个爆款标题模板（每个说明适用场景）');
    sb.writeln('2. 5个高点击关键词');
    sb.writeln('3. 标题写作的3个核心技巧');

    return chat(
      '你是抖音爆款标题专家，深谙抖音算法推荐逻辑，擅长分析高播放视频的标题套路，提炼可复用的标题公式和关键词库。',
      sb.toString(),
    );
  }

  /// Channel diagnosis
  Future<String> channelDiagnosis(Map<String, dynamic> stats) async {
    final sb = StringBuffer();
    sb.writeln('请帮我诊断抖音频道整体表现：');
    sb.writeln('总视频数：${stats['total_videos'] ?? 0}');
    sb.writeln('总播放量：${stats['total_plays'] ?? 0}');
    sb.writeln('平均点赞数：${stats['avg_likes']?.toStringAsFixed(0) ?? '--'}');
    sb.writeln('平均评论数：${stats['avg_comments']?.toStringAsFixed(0) ?? '--'}');
    sb.writeln('平均分享数：${stats['avg_shares']?.toStringAsFixed(0) ?? '--'}');
    sb.writeln('平均完播率：${stats['avg_finish_rate']?.toStringAsFixed(1) ?? '--'}%');
    sb.writeln('平均观看时长：${stats['avg_watch_duration']?.toStringAsFixed(1) ?? '--'}s');
    if ((stats['avg_cover_ctr'] as double?) != null && stats['avg_cover_ctr'] > 0) {
      sb.writeln('平均封面点击率：${stats['avg_cover_ctr']?.toStringAsFixed(1) ?? '--'}%');
    }
    if ((stats['avg_two_second_exit_rate'] as double?) != null && stats['avg_two_second_exit_rate'] > 0) {
      sb.writeln('平均2秒跳出率：${stats['avg_two_second_exit_rate']?.toStringAsFixed(1) ?? '--'}%');
    }
    sb.writeln();
    sb.writeln('请按以下格式输出诊断：');
    sb.writeln('【频道评级】S/A/B/C/D（基于综合表现）');
    sb.writeln('【核心优势】1-2条，用数据支撑');
    sb.writeln('【主要问题】1-2条，指出最严重的短板');
    sb.writeln('【行动建议】2条优先级最高的改进方向');

    return chat(
      '你是抖音频道运营诊断专家，熟悉抖音流量池机制、账号标签体系、内容垂直化策略。能够快速识别账号的核心问题并给出优先级最高的改进建议。',
      sb.toString(),
    );
  }

  /// Audience profile interpretation
  Future<String> audienceInterpretation({
    required double maleRatio,
    required Map<String, double> ageDistribution,
    required List<MapEntry<String, double>> topRegions,
  }) async {
    final sb = StringBuffer();
    sb.writeln('这是我抖音账号的粉丝画像数据：');
    sb.writeln('性别比例：男性${(maleRatio * 100).toStringAsFixed(1)}%，女性${((1 - maleRatio) * 100).toStringAsFixed(1)}%');
    if (ageDistribution.isNotEmpty) {
      sb.writeln('年龄分布：');
      ageDistribution.forEach((k, v) {
        sb.writeln('  $k: ${(v * 100).toStringAsFixed(1)}%');
      });
    }
    if (topRegions.isNotEmpty) {
      sb.writeln('地域TOP5：');
      for (int i = 0; i < topRegions.length && i < 5; i++) {
        sb.writeln('  ${i + 1}. ${topRegions[i].key}: ${(topRegions[i].value * 100).toStringAsFixed(1)}%');
      }
    }
    sb.writeln();
    sb.writeln('请输出：');
    sb.writeln('1. 粉丝画像总结（一句话概括核心人群）');
    sb.writeln('2. 内容创作建议（结合受众特点给出3条方向）');
    sb.writeln('3. 商业化建议（这类人群适合什么变现方式）');

    return chat(
      '你是抖音粉丝运营专家，精通受众分析和用户画像应用，能够根据粉丝画像给出精准的内容定位和商业化建议。',
      sb.toString(),
    );
  }
}
