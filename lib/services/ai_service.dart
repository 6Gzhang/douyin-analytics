import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static const String _endpoint = 'https://api.siliconflow.cn/v1/chat/completions';
  static const String _defaultModel = 'Qwen/Qwen2.5-7B-Instruct';

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('siliconflow_api_key');
  }

  Future<String> _getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('siliconflow_model') ?? _defaultModel;
  }

  Future<void> updateApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('siliconflow_api_key', key);
  }

  Future<void> setModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('siliconflow_model', model);
  }

  Future<void> _incrementUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('ai_usage_count') ?? 0;
    await prefs.setInt('ai_usage_count', count + 1);
  }

  Future<void> _addTokenEstimate(String content) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getInt('ai_estimated_tokens') ?? 0;
    await prefs.setInt('ai_estimated_tokens', existing + (content.length ~/ 3));
  }

  Future<String> chat(String systemPrompt, String userMessage) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return '请先在设置页配置硅基流动 API Key（免费使用 Qwen2.5-7B）。';
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
          'temperature': 0.7,
          'top_p': 0.9,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
        }),
      ).timeout(const Duration(seconds: 60));

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
          return 'API Key 无效或已过期，请在设置页更新硅基流动 API Key。';
        }
        if (msg.contains('quota') || msg.contains('insufficient')) {
          return 'API 额度已耗尽，请前往硅基流动控制台查看用量。';
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

  Future<String> analyzeVideo(
      String title, Map<String, dynamic> metrics) async {
    final playCount = metrics['play_count'] ?? 0;
    final likeCount = metrics['like_count'] ?? 0;
    final commentCount = metrics['comment_count'] ?? 0;
    final shareCount = metrics['share_count'] ?? 0;
    final collectCount = metrics['collect_count'] ?? 0;
    final finishRate = (metrics['finish_rate'] as double?) ?? 0;
    final avgWatch = (metrics['avg_watch_duration'] as double?) ?? 0;
    final twoSecExit = (metrics['two_second_exit_rate'] as double?) ?? 0;
    final coverCtr = (metrics['cover_ctr'] as double?) ?? 0;

    final likeRate = playCount > 0 ? likeCount / playCount * 100 : 0;
    final commentRate = playCount > 0 ? commentCount / playCount * 100 : 0;
    final shareRate = playCount > 0 ? shareCount / playCount * 100 : 0;
    final collectRate = playCount > 0 ? collectCount / playCount * 100 : 0;

    final sb = StringBuffer();
    sb.writeln('抖音单条视频深度分析：');
    sb.writeln('视频标题：$title');
    sb.writeln('');
    sb.writeln('【基础数据：');
    sb.writeln('播放量：$playCount');
    sb.writeln('点赞：$likeCount (点赞率 ${likeRate.toStringAsFixed(2)}%)');
    sb.writeln('评论：$commentCount (评论率 ${commentRate.toStringAsFixed(2)}%)');
    sb.writeln('分享：$shareCount (分享率 ${shareRate.toStringAsFixed(2)}%)');
    sb.writeln('收藏：$collectCount (收藏率 ${collectRate.toStringAsFixed(2)}%)');
    sb.writeln('');
    sb.writeln('【完播数据：');
    sb.writeln('完播率：${finishRate.toStringAsFixed(1)}%');
    sb.writeln('平均观看时长：${avgWatch.toStringAsFixed(1)}秒');
    if (twoSecExit > 0) sb.writeln('2秒跳出率：${twoSecExit.toStringAsFixed(1)}%');
    if (coverCtr > 0) sb.writeln('封面点击率：${coverCtr.toStringAsFixed(1)}%');
    sb.writeln('');
    sb.writeln('请按以下格式输出深度分析报告：');
    sb.writeln('');
    sb.writeln('【视频评级】S/A/B/C/D');
    sb.writeln('【一句话总结】用一句话概括这条视频的核心问题或亮点');
    sb.writeln('');
    sb.writeln('【三大亮点】');
    sb.writeln('1. ...');
    sb.writeln('2. ...');
    sb.writeln('3. ...');
    sb.writeln('');
    sb.writeln('【核心问题（按严重度排序）】');
    sb.writeln('1. 问题描述 + 对应数据指标');
    sb.writeln('2. 问题描述 + 对应数据指标');
    sb.writeln('');
    sb.writeln('【优化建议（按优先级排序，每条具体可执行）】');
    sb.writeln('1. [高优] 具体建议 + 预期效果');
    sb.writeln('2. [中优] 具体建议 + 预期效果');
    sb.writeln('3. [低优] 具体建议 + 预期效果');
    sb.writeln('');
    sb.writeln('【内容方向参考】');
    sb.writeln('推荐3个可以延伸的选题方向');
    sb.writeln('');
    sb.writeln('回答要专业、具体、可落地，用数据说话，避免空话套话。');

    return chat(
      '你是拥有8年抖音运营经验的资深分析师，精通抖音算法逻辑、流量池机制、完播率优化、互动率提升。分析要一针见血，建议要具体可执行，用数据支撑判断。不要说空话套话。',
      sb.toString(),
    );
  }

  Future<String> suggestTitles(List<Map<String, dynamic>> topVideos) async {
    final sb = StringBuffer();
    sb.writeln('我的高播放视频数据：');
    for (int i = 0; i < topVideos.length && i < 8; i++) {
      final v = topVideos[i];
      final plays = v['plays'] ?? 0;
      final title = v['title'] ?? '无标题';
      sb.writeln('${i + 1}. 《$title》播放：$plays');
    }
    sb.writeln('');
    sb.writeln('请基于这些高播放视频的标题风格，输出：');
    sb.writeln('');
    sb.writeln('【爆款标题公式提炼】');
    sb.writeln('从以上视频中提炼3种可复用的标题公式，每种配一个示例');
    sb.writeln('');
    sb.writeln('【高点击关键词库】');
    sb.writeln('按类别分类（数字类/疑问类/悬念类/情绪类），共15个关键词');
    sb.writeln('');
    sb.writeln('【标题优化建议】');
    sb.writeln('3条可直接套用的优化方向');
    sb.writeln('');
    sb.writeln('【下周选题推荐】');
    sb.writeln('基于爆款方向推荐5个选题方向，每个配标题示例');

    return chat(
      '你是抖音爆款标题专家，深谙抖音算法推荐逻辑，擅长从高播放视频中提炼可复用的标题公式和关键词库。回答要具体、可落地。',
      sb.toString(),
    );
  }

  Future<String> channelDiagnosis(Map<String, dynamic> stats) async {
    final totalVideos = stats['total_videos'] ?? 0;
    final totalPlays = stats['total_plays'] ?? 0;
    final totalLikes = stats['total_likes'] ?? 0;
    final totalComments = stats['total_comments'] ?? 0;
    final totalShares = stats['total_shares'] ?? 0;
    final avgLikes = stats['avg_likes'] ?? 0.0;
    final avgFinishRate = stats['avg_finish_rate'] ?? 0.0;
    final avgWatch = stats['avg_watch_duration'] ?? 0.0;
    final avgCoverCtr = stats['avg_cover_ctr'] ?? 0.0;
    final avgTwoSecExit = stats['avg_two_second_exit_rate'] ?? 0.0;
    final totalProfileVisits = stats['total_profile_visits'] ?? 0;

    final likeRate = totalPlays > 0 ? totalLikes / totalPlays * 100 : 0;
    final commentRate = totalPlays > 0 ? totalComments / totalPlays * 100 : 0;
    final shareRate = totalPlays > 0 ? totalShares / totalPlays * 100 : 0;
    final avgPlays = totalVideos > 0 ? totalPlays / totalVideos : 0;

    final sb = StringBuffer();
    sb.writeln('抖音频道整体诊断数据：');
    sb.writeln('');
    sb.writeln('【基础数据】');
    sb.writeln('视频总数：$totalVideos 条');
    sb.writeln('总播放量：$totalPlays');
    sb.writeln('平均播放：${avgPlays.toStringAsFixed(0)}');
    sb.writeln('');
    sb.writeln('【互动数据】');
    sb.writeln('总点赞：$totalLikes (点赞率 ${likeRate.toStringAsFixed(2)}%)');
    sb.writeln('总评论：$totalComments (评论率 ${commentRate.toStringAsFixed(2)}%)');
    sb.writeln('总分享：$totalShares (分享率 ${shareRate.toStringAsFixed(2)}%)');
    sb.writeln('平均点赞：${avgLikes.toStringAsFixed(0)}');
    sb.writeln('');
    sb.writeln('【完播数据】');
    sb.writeln('平均完播率：${avgFinishRate.toStringAsFixed(1)}%');
    sb.writeln('平均观看时长：${avgWatch.toStringAsFixed(1)}秒');
    if (avgTwoSecExit > 0) sb.writeln('平均2秒跳出率：${avgTwoSecExit.toStringAsFixed(1)}%');
    if (avgCoverCtr > 0) sb.writeln('平均封面点击率：${avgCoverCtr.toStringAsFixed(1)}%');
    if (totalProfileVisits > 0) sb.writeln('主页访问量：$totalProfileVisits');
    sb.writeln('');
    sb.writeln('请输出频道诊断报告，格式如下：');
    sb.writeln('');
    sb.writeln('【频道评级】S/A/B/C/D + 一句话评级理由');
    sb.writeln('');
    sb.writeln('【频道定位分析】');
    sb.writeln('用2-3句话概括频道目前所处阶段和核心特征');
    sb.writeln('');
    sb.writeln('【核心优势】（1-2条，配数据支撑）');
    sb.writeln('1. ...');
    sb.writeln('');
    sb.writeln('【三大短板】（按严重程度排序，每条配对应数据）');
    sb.writeln('1. 问题 + 数据表现');
    sb.writeln('2. 问题 + 数据表现');
    sb.writeln('');
    sb.writeln('【增长瓶颈分析】');
    sb.writeln('分析当前最主要的增长障碍是什么');
    sb.writeln('');
    sb.writeln('【月度行动计划】（按优先级排序）');
    sb.writeln('1. [第1优先级] 具体行动 + 预期效果');
    sb.writeln('2. [第2优先级] 具体行动 + 预期效果');
    sb.writeln('3. [第3优先级] 具体行动 + 预期效果');
    sb.writeln('');
    sb.writeln('回答要专业、深入、可落地，用数据说话，避免空话套话。');

    return chat(
      '你是抖音频道运营诊断专家，熟悉抖音流量池机制、账号标签体系、内容垂直化策略。能够快速识别账号核心问题并给出优先级最高的改进建议。回答要一针见血，可落地执行。',
      sb.toString(),
    );
  }

  Future<String> audienceInterpretation({
    required double maleRatio,
    required Map<String, double> ageDistribution,
    required List<MapEntry<String, double>> topRegions,
  }) async {
    final femaleRatio = 1 - maleRatio;
    final sb = StringBuffer();
    sb.writeln('抖音粉丝画像深度分析：');
    sb.writeln('');
    sb.writeln('性别比例：');
    sb.writeln('男性：${(maleRatio * 100).toStringAsFixed(1)}%');
    sb.writeln('女性：${(femaleRatio * 100).toStringAsFixed(1)}%');
    sb.writeln('');
    if (ageDistribution.isNotEmpty) {
      sb.writeln('年龄分布：');
      ageDistribution.forEach((k, v) {
        sb.writeln('  $k: ${(v * 100).toStringAsFixed(1)}%');
      });
      sb.writeln('');
    }
    if (topRegions.isNotEmpty) {
      sb.writeln('地域TOP5：');
      for (int i = 0; i < topRegions.length && i < 5; i++) {
        sb.writeln('  ${i + 1}. ${topRegions[i].key}: ${(topRegions[i].value * 100).toStringAsFixed(1)}%');
      }
      sb.writeln('');
    }
    sb.writeln('请输出粉丝画像深度解读报告：');
    sb.writeln('');
    sb.writeln('【核心人群画像】');
    sb.writeln('用一句话精准概括核心粉丝群体特征');
    sb.writeln('');
    sb.writeln('【人群特征解读】');
    sb.writeln('3个核心特征，每个配数据支撑');
    sb.writeln('');
    sb.writeln('【内容创作建议】');
    sb.writeln('3条内容方向建议，结合人群特点');
    sb.writeln('');
    sb.writeln('【商业化建议】');
    sb.writeln('3个适合的变现方向及理由');
    sb.writeln('');
    sb.writeln('【运营策略建议】');
    sb.writeln('2条针对该人群的运营策略');

    return chat(
      '你是抖音粉丝运营专家，精通受众分析和用户画像应用，能够根据粉丝画像给出精准的内容定位和商业化建议。分析要深入、具体、可落地。',
      sb.toString(),
    );
  }

  Future<String> contentStrategyAnalysis(List<Map<String, dynamic>> videos) async {
    if (videos.isEmpty) return '暂无视频数据';
    final sb = StringBuffer();
    sb.writeln('内容策略分析 - 共${videos.length}条视频');
    sb.writeln('');

    final sortedByPlays = List<Map<String, dynamic>>.from(videos)
      ..sort((a, b) =>
          ((b['play_count'] ?? 0).compareTo((a['play_count'] ?? 0)));
    final top3 = sortedByPlays.take(3).toList();
    final bottom3 = sortedByPlays.length > 3
        ? sortedByPlays.sublist(sortedByPlays.length - 3)
        : <Map<String, dynamic>>[];

    sb.writeln('【高播放视频TOP3】');
    for (int i = 0; i < top3.length; i++) {
      sb.writeln('${i + 1}. ${top3[i]['title'] ?? ''} - ${top3[i]['play_count'] ?? 0}播放');
    }
    sb.writeln('');

    if (bottom3.isNotEmpty) {
      sb.writeln('【低播放视频Bottom3】');
      for (int i = 0; i < bottom3.length; i++) {
        sb.writeln('${i + 1}. ${bottom3[i]['title'] ?? ''} - ${bottom3[i]['play_count'] ?? 0}播放');
      }
      sb.writeln('');
    }

    sb.writeln('请输出内容策略分析报告：');
    sb.writeln('');
    sb.writeln('【内容风格诊断】');
    sb.writeln('当前内容的整体风格定位和问题');
    sb.writeln('');
    sb.writeln('【爆款基因分析】');
    sb.writeln('高播放视频有哪些共同特点？');
    sb.writeln('');
    sb.writeln('【内容优化方向】');
    sb.writeln('3个最应该优化的内容方向');
    sb.writeln('');
    sb.writeln('【选题建议】');
    sb.writeln('5个可直接做的选题方向');

    return chat(
      '你是抖音内容策略专家，擅长从数据中发现内容规律，提炼爆款基因，给出可落地的内容优化建议。',
      sb.toString(),
    );
  }
}
