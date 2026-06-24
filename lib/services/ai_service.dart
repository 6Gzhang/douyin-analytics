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
      ).timeout(const Duration(seconds: 90));

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
    final fiveSecFinish = (metrics['five_second_finish_rate'] as double?) ?? 0;
    final profileVisits = metrics['profile_visits'] ?? 0;
    final fullPlayCount = metrics['full_play_count'] ?? 0;
    final duration = (metrics['duration'] as double?) ?? 0;

    final likeRate = playCount > 0 ? likeCount / playCount * 100 : 0;
    final commentRate = playCount > 0 ? commentCount / playCount * 100 : 0;
    final shareRate = playCount > 0 ? shareCount / playCount * 100 : 0;
    final collectRate = playCount > 0 ? collectCount / playCount * 100 : 0;
    final interactionRate = playCount > 0
        ? (likeCount + commentCount + shareCount + collectCount) /
            playCount *
            100
        : 0;
    final profileVisitRate =
        playCount > 0 ? profileVisits / playCount * 100 : 0;

    final sb = StringBuffer();
    sb.writeln('抖音单条视频深度分析：');
    sb.writeln('视频标题：$title');
    if (duration > 0) sb.writeln('视频时长：${duration.toStringAsFixed(0)}秒');
    sb.writeln('');
    sb.writeln('【基础流量数据】');
    sb.writeln('播放量：$playCount');
    sb.writeln('完整播放：$fullPlayCount');
    sb.writeln('主页访问：$profileVisits (主页转化率 ${profileVisitRate.toStringAsFixed(2)}%)');
    sb.writeln('');
    sb.writeln('【互动数据】');
    sb.writeln('点赞：$likeCount (点赞率 ${likeRate.toStringAsFixed(2)}%)');
    sb.writeln('评论：$commentCount (评论率 ${commentRate.toStringAsFixed(2)}%)');
    sb.writeln('分享：$shareCount (分享率 ${shareRate.toStringAsFixed(2)}%)');
    sb.writeln('收藏：$collectCount (收藏率 ${collectRate.toStringAsFixed(2)}%)');
    sb.writeln('综合互动率：${interactionRate.toStringAsFixed(2)}%');
    sb.writeln('');
    sb.writeln('【完播与留存数据】');
    sb.writeln('整体完播率：${finishRate.toStringAsFixed(1)}%');
    sb.writeln('平均观看时长：${avgWatch.toStringAsFixed(1)}秒');
    if (duration > 0) {
      sb.writeln('观看完成度：${(avgWatch / duration * 100).toStringAsFixed(1)}%');
    }
    if (twoSecExit > 0) sb.writeln('2秒跳出率：${twoSecExit.toStringAsFixed(1)}%');
    if (fiveSecFinish > 0) sb.writeln('5秒完播率：${fiveSecFinish.toStringAsFixed(1)}%');
    if (coverCtr > 0) sb.writeln('封面点击率：${coverCtr.toStringAsFixed(1)}%');
    sb.writeln('');
    sb.writeln('【关键漏斗分析】');
    sb.writeln('曝光→播放(封面CTR): ${coverCtr > 0 ? "${coverCtr.toStringAsFixed(1)}%" : "未知"}');
    sb.writeln('播放→5秒留存: ${fiveSecFinish > 0 ? "${fiveSecFinish.toStringAsFixed(1)}%" : "未知"}');
    sb.writeln('5秒→完播: ${fiveSecFinish > 0 && finishRate > 0 ? "${(finishRate / fiveSecFinish * 100).toStringAsFixed(1)}%" : "未知"}');
    sb.writeln('播放→点赞: ${likeRate.toStringAsFixed(2)}%');
    sb.writeln('播放→主页访问: ${profileVisitRate.toStringAsFixed(2)}%');
    sb.writeln('');
    sb.writeln('请按以下格式输出深度分析报告：');
    sb.writeln('');
    sb.writeln('【视频评级】S/A/B/C/D + 一句话评级理由');
    sb.writeln('');
    sb.writeln('【核心数据诊断】');
    sb.writeln('用2-3句话概括这条视频最核心的数据表现');
    sb.writeln('');
    sb.writeln('【三大亮点】（配数据支撑）');
    sb.writeln('1. 亮点描述 + 对应数据');
    sb.writeln('2. 亮点描述 + 对应数据');
    sb.writeln('3. 亮点描述 + 对应数据');
    sb.writeln('');
    sb.writeln('【核心问题】（按严重度排序，每条配数据）');
    sb.writeln('1. 问题描述 + 数据表现 + 影响程度');
    sb.writeln('2. 问题描述 + 数据表现 + 影响程度');
    sb.writeln('3. 问题描述 + 数据表现 + 影响程度');
    sb.writeln('');
    sb.writeln('【流失点分析】');
    sb.writeln('分析观众最可能在哪个环节流失（开头/中间/结尾），以及原因推测');
    sb.writeln('');
    sb.writeln('【优化建议】（按优先级排序，每条具体可执行）');
    sb.writeln('1. [高优] 具体建议 + 预期提升效果');
    sb.writeln('2. [中优] 具体建议 + 预期提升效果');
    sb.writeln('3. [低优] 具体建议 + 预期提升效果');
    sb.writeln('');
    sb.writeln('【内容延伸方向】');
    sb.writeln('推荐3个可以延伸的选题方向，每个配标题示例');
    sb.writeln('');
    sb.writeln('回答要专业、具体、可落地，用数据说话，避免空话套话。');

    return chat(
      '你是拥有8年抖音运营经验的资深分析师，精通抖音算法逻辑、流量池机制、完播率优化、互动率提升、漏斗分析。分析要一针见血，建议要具体可执行，用数据支撑判断。不要说空话套话。',
      sb.toString(),
    );
  }

  Future<String> suggestTitles(List<Map<String, dynamic>> topVideos) async {
    final sb = StringBuffer();
    sb.writeln('我的高播放视频数据：');
    for (int i = 0; i < topVideos.length && i < 10; i++) {
      final v = topVideos[i];
      final plays = v['play_count'] ?? v['plays'] ?? 0;
      final title = v['title'] ?? '无标题';
      final finishRate = (v['finish_rate'] as double?) ?? 0;
      sb.writeln('${i + 1}. 《$title》播放：$plays${finishRate > 0 ? "，完播率：${finishRate.toStringAsFixed(1)}%" : ""}');
    }
    sb.writeln('');
    sb.writeln('请基于这些高播放视频的标题风格，输出：');
    sb.writeln('');
    sb.writeln('【爆款标题公式提炼】');
    sb.writeln('从以上视频中提炼5种可复用的标题公式，每种配一个示例');
    sb.writeln('');
    sb.writeln('【高点击关键词库】');
    sb.writeln('按类别分类（数字类/疑问类/悬念类/情绪类/干货类/反差类），共20个关键词');
    sb.writeln('');
    sb.writeln('【标题避坑指南】');
    sb.writeln('5个常见的标题错误及避免方法');
    sb.writeln('');
    sb.writeln('【标题优化建议】');
    sb.writeln('5条可直接套用的优化方向，每条配前后对比示例');
    sb.writeln('');
    sb.writeln('【下周选题推荐】');
    sb.writeln('基于爆款方向推荐8个选题方向，每个配标题示例');

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
    final totalCollects = stats['total_collects'] ?? 0;
    final avgLikes = stats['avg_likes'] ?? 0.0;
    final avgFinishRate = stats['avg_finish_rate'] ?? 0.0;
    final avgWatch = stats['avg_watch_duration'] ?? 0.0;
    final avgCoverCtr = stats['avg_cover_ctr'] ?? 0.0;
    final avgTwoSecExit = stats['avg_two_second_exit_rate'] ?? 0.0;
    final totalProfileVisits = stats['total_profile_visits'] ?? 0;
    final totalFullPlays = stats['total_full_plays'] ?? 0;
    final avgFiveSecFinish = stats['avg_five_second_finish_rate'] ?? 0.0;

    final likeRate = totalPlays > 0 ? totalLikes / totalPlays * 100 : 0;
    final commentRate = totalPlays > 0 ? totalComments / totalPlays * 100 : 0;
    final shareRate = totalPlays > 0 ? totalShares / totalPlays * 100 : 0;
    final collectRate = totalPlays > 0 ? totalCollects / totalPlays * 100 : 0;
    final avgPlays = totalVideos > 0 ? totalPlays / totalVideos : 0;
    final interactionRate = totalPlays > 0
        ? (totalLikes + totalComments + totalShares + totalCollects) /
            totalPlays *
            100
        : 0;
    final profileVisitRate =
        totalPlays > 0 ? totalProfileVisits / totalPlays * 100 : 0;

    final sb = StringBuffer();
    sb.writeln('抖音频道整体诊断报告');
    sb.writeln('');
    sb.writeln('【频道规模】');
    sb.writeln('视频总数：$totalVideos 条');
    sb.writeln('总播放量：$totalPlays');
    sb.writeln('平均播放：${avgPlays.toStringAsFixed(0)}');
    sb.writeln('总主页访问：$totalProfileVisits (转化率 ${profileVisitRate.toStringAsFixed(2)}%)');
    sb.writeln('');
    sb.writeln('【互动数据汇总】');
    sb.writeln('总点赞：$totalLikes (点赞率 ${likeRate.toStringAsFixed(2)}%)');
    sb.writeln('总评论：$totalComments (评论率 ${commentRate.toStringAsFixed(2)}%)');
    sb.writeln('总分享：$totalShares (分享率 ${shareRate.toStringAsFixed(2)}%)');
    sb.writeln('总收藏：$totalCollects (收藏率 ${collectRate.toStringAsFixed(2)}%)');
    sb.writeln('综合互动率：${interactionRate.toStringAsFixed(2)}%');
    sb.writeln('平均点赞：${avgLikes.toStringAsFixed(0)}');
    sb.writeln('');
    sb.writeln('【完播与留存数据】');
    sb.writeln('平均完播率：${avgFinishRate.toStringAsFixed(1)}%');
    sb.writeln('平均观看时长：${avgWatch.toStringAsFixed(1)}秒');
    if (avgFiveSecFinish > 0) sb.writeln('平均5秒完播率：${avgFiveSecFinish.toStringAsFixed(1)}%');
    if (avgTwoSecExit > 0) sb.writeln('平均2秒跳出率：${avgTwoSecExit.toStringAsFixed(1)}%');
    if (avgCoverCtr > 0) sb.writeln('平均封面点击率：${avgCoverCtr.toStringAsFixed(1)}%');
    sb.writeln('完整播放总数：$totalFullPlays');
    sb.writeln('');
    sb.writeln('【流量漏斗健康度评估】');
    sb.writeln('第1层 - 封面点击(曝光→播放): ${avgCoverCtr > 0 ? "${avgCoverCtr.toStringAsFixed(1)}%" : "数据不足"}');
    sb.writeln('第2层 - 5秒留存(播放→5秒): ${avgFiveSecFinish > 0 ? "${avgFiveSecFinish.toStringAsFixed(1)}%" : "数据不足"}');
    sb.writeln('第3层 - 完播(5秒→完播): ${avgFiveSecFinish > 0 && avgFinishRate > 0 ? "${(avgFinishRate / avgFiveSecFinish * 100).toStringAsFixed(1)}%" : "数据不足"}');
    sb.writeln('第4层 - 互动(完播→互动): ${avgFinishRate > 0 ? "${(interactionRate / avgFinishRate * 100).toStringAsFixed(1)}%" : "数据不足"}');
    sb.writeln('第5层 - 转化(互动→关注): 需粉丝数据');
    sb.writeln('');
    sb.writeln('请输出完整的频道诊断报告，格式如下：');
    sb.writeln('');
    sb.writeln('【频道评级】S/A/B/C/D + 一句话评级理由');
    sb.writeln('');
    sb.writeln('【频道阶段定位】');
    sb.writeln('判断频道目前处于：冷启动期/成长期/爆发期/瓶颈期/衰退期，并说明判断依据');
    sb.writeln('');
    sb.writeln('【核心优势】（2-3条，配数据支撑）');
    sb.writeln('1. 优势描述 + 数据表现');
    sb.writeln('2. 优势描述 + 数据表现');
    sb.writeln('');
    sb.writeln('【五大短板】（按严重程度排序，每条配对应数据）');
    sb.writeln('1. 问题 + 数据表现 + 影响分析');
    sb.writeln('2. 问题 + 数据表现 + 影响分析');
    sb.writeln('3. 问题 + 数据表现 + 影响分析');
    sb.writeln('4. 问题 + 数据表现 + 影响分析');
    sb.writeln('5. 问题 + 数据表现 + 影响分析');
    sb.writeln('');
    sb.writeln('【流量漏斗诊断】');
    sb.writeln('分析5层漏斗中每层的健康度，找出最大的流失环节');
    sb.writeln('');
    sb.writeln('【增长瓶颈分析】');
    sb.writeln('深入分析当前最主要的增长障碍是什么，以及为什么');
    sb.writeln('');
    sb.writeln('【月度行动计划】（按优先级排序，共5项）');
    sb.writeln('1. [第1优先级] 具体行动 + 执行方法 + 预期效果');
    sb.writeln('2. [第2优先级] 具体行动 + 执行方法 + 预期效果');
    sb.writeln('3. [第3优先级] 具体行动 + 执行方法 + 预期效果');
    sb.writeln('4. [第4优先级] 具体行动 + 执行方法 + 预期效果');
    sb.writeln('5. [第5优先级] 具体行动 + 执行方法 + 预期效果');
    sb.writeln('');
    sb.writeln('【内容方向建议】');
    sb.writeln('推荐3个最应该深耕的内容方向，说明理由');
    sb.writeln('');
    sb.writeln('回答要专业、深入、可落地，用数据说话，避免空话套话。');

    return chat(
      '你是抖音频道运营诊断专家，熟悉抖音流量池机制、账号标签体系、内容垂直化策略、漏斗分析方法。能够快速识别账号核心问题并给出优先级最高的改进建议。回答要一针见血，可落地执行。',
      sb.toString(),
    );
  }

  Future<String> audienceInterpretation({
    required double maleRatio,
    required Map<String, double> ageDistribution,
    required List<MapEntry<String, double>> topRegions,
    Map<String, double>? tgiData,
    double? avgWatchDuration,
    double? avgFinishRate,
    int? totalVideos,
  }) async {
    final femaleRatio = 1 - maleRatio;
    final sb = StringBuffer();
    sb.writeln('抖音粉丝画像深度分析：');
    sb.writeln('');
    sb.writeln('【性别比例】');
    sb.writeln('男性：${(maleRatio * 100).toStringAsFixed(1)}%');
    sb.writeln('女性：${(femaleRatio * 100).toStringAsFixed(1)}%');
    sb.writeln('');
    if (ageDistribution.isNotEmpty) {
      sb.writeln('【年龄分布】');
      ageDistribution.forEach((k, v) {
        sb.writeln('  $k: ${(v * 100).toStringAsFixed(1)}%');
      });
      sb.writeln('');
    }
    if (topRegions.isNotEmpty) {
      sb.writeln('【地域TOP10】');
      for (int i = 0; i < topRegions.length && i < 10; i++) {
        sb.writeln('  ${i + 1}. ${topRegions[i].key}: ${(topRegions[i].value * 100).toStringAsFixed(1)}%');
      }
      sb.writeln('');
    }
    if (tgiData != null && tgiData.isNotEmpty) {
      sb.writeln('【TGI兴趣标签】');
      tgiData.forEach((k, v) {
        sb.writeln('  $k: TGI ${v.toStringAsFixed(0)}');
      });
      sb.writeln('');
    }
    if (avgWatchDuration != null && avgWatchDuration > 0) {
      sb.writeln('【内容消费特征】');
      sb.writeln('平均观看时长：${avgWatchDuration.toStringAsFixed(1)}秒');
      if (avgFinishRate != null && avgFinishRate > 0) {
        sb.writeln('平均完播率：${avgFinishRate.toStringAsFixed(1)}%');
      }
      if (totalVideos != null) {
        sb.writeln('已发布视频：$totalVideos 条');
      }
      sb.writeln('');
    }
    sb.writeln('请输出粉丝画像深度解读报告：');
    sb.writeln('');
    sb.writeln('【核心人群画像】');
    sb.writeln('用一句话精准概括核心粉丝群体特征（年龄+性别+地域+兴趣）');
    sb.writeln('');
    sb.writeln('【人群特征深度解读】');
    sb.writeln('5个核心特征，每个配数据支撑和运营启示');
    sb.writeln('');
    sb.writeln('【内容创作建议】');
    sb.writeln('5条内容方向建议，每条结合人群特点，配具体示例');
    sb.writeln('');
    sb.writeln('【商业化变现建议】');
    sb.writeln('5个适合的变现方向及理由，按优先级排序');
    sb.writeln('');
    sb.writeln('【运营策略建议】');
    sb.writeln('3条针对该人群的运营策略（涨粉/留存/互动）');
    sb.writeln('');
    sb.writeln('【最佳发布时间建议】');
    sb.writeln('根据人群特征推测最佳发布时间段及理由');

    return chat(
      '你是抖音粉丝运营专家，精通受众分析、用户画像应用、人群精细化运营。能够根据粉丝画像给出精准的内容定位、商业化建议和运营策略。分析要深入、具体、可落地。',
      sb.toString(),
    );
  }

  Future<String> contentStrategyAnalysis(List<Map<String, dynamic>> videos) async {
    if (videos.isEmpty) return '暂无视频数据';
    final sb = StringBuffer();
    sb.writeln('内容策略深度分析 - 共${videos.length}条视频');
    sb.writeln('');

    final sortedByPlays = List<Map<String, dynamic>>.from(videos)
      ..sort((a, b) =>
          ((b['play_count'] ?? 0).compareTo((a['play_count'] ?? 0))));
    final top5 = sortedByPlays.take(5).toList();
    final bottom5 = sortedByPlays.length > 5
        ? sortedByPlays.sublist(sortedByPlays.length - 5)
        : <Map<String, dynamic>>[];

    final sortedByFinish = List<Map<String, dynamic>>.from(videos)
      ..where((v) => (v['finish_rate'] ?? 0) > 0)
      .toList()
      ..sort((a, b) =>
          ((b['finish_rate'] ?? 0).compareTo((a['finish_rate'] ?? 0))));
    final topFinish = sortedByFinish.take(3).toList();
    final lowFinish = sortedByFinish.length > 3
        ? sortedByFinish.sublist(sortedByFinish.length - 3)
        : <Map<String, dynamic>>[];

    sb.writeln('【高播放视频TOP5】');
    for (int i = 0; i < top5.length; i++) {
      final fr = (top5[i]['finish_rate'] as double?) ?? 0;
      sb.writeln('${i + 1}. ${top5[i]['title'] ?? ''} - ${top5[i]['play_count'] ?? 0}播放${fr > 0 ? "，完播率${fr.toStringAsFixed(1)}%" : ""}');
    }
    sb.writeln('');

    if (bottom5.isNotEmpty) {
      sb.writeln('【低播放视频Bottom5】');
      for (int i = 0; i < bottom5.length; i++) {
        final fr = (bottom5[i]['finish_rate'] as double?) ?? 0;
        sb.writeln('${i + 1}. ${bottom5[i]['title'] ?? ''} - ${bottom5[i]['play_count'] ?? 0}播放${fr > 0 ? "，完播率${fr.toStringAsFixed(1)}%" : ""}');
      }
      sb.writeln('');
    }

    if (topFinish.isNotEmpty) {
      sb.writeln('【高完播率视频TOP3】');
      for (int i = 0; i < topFinish.length; i++) {
        sb.writeln('${i + 1}. ${topFinish[i]['title'] ?? ''} - 完播率${((topFinish[i]['finish_rate'] as double?) ?? 0).toStringAsFixed(1)}%');
      }
      sb.writeln('');
    }

    if (lowFinish.isNotEmpty) {
      sb.writeln('【低完播率视频Bottom3】');
      for (int i = 0; i < lowFinish.length; i++) {
        sb.writeln('${i + 1}. ${lowFinish[i]['title'] ?? ''} - 完播率${((lowFinish[i]['finish_rate'] as double?) ?? 0).toStringAsFixed(1)}%');
      }
      sb.writeln('');
    }

    sb.writeln('请输出内容策略深度分析报告：');
    sb.writeln('');
    sb.writeln('【内容风格诊断】');
    sb.writeln('当前内容的整体风格定位、优势和问题');
    sb.writeln('');
    sb.writeln('【爆款基因分析】');
    sb.writeln('高播放/高完播视频有哪些共同特点？从标题、封面、内容结构、时长等维度分析');
    sb.writeln('');
    sb.writeln('【低质内容病因分析】');
    sb.writeln('低播放/低完播视频的共性问题是什么？为什么表现不好？');
    sb.writeln('');
    sb.writeln('【内容结构优化建议】');
    sb.writeln('从黄金3秒、信息密度、节奏把控、结尾引导四个维度给出具体优化方法');
    sb.writeln('');
    sb.writeln('【内容选题矩阵】');
    sb.writeln('建议建立怎样的选题矩阵？各类内容占比如何分配？');
    sb.writeln('');
    sb.writeln('【内容优化优先级】');
    sb.writeln('按优先级排序的5个内容优化方向，每条配具体执行方法和预期效果');
    sb.writeln('');
    sb.writeln('【下周选题推荐】');
    sb.writeln('基于数据分析推荐10个可直接做的选题方向，每个配标题示例');

    return chat(
      '你是抖音内容策略专家，擅长从数据中发现内容规律，提炼爆款基因，诊断内容问题，给出可落地的内容优化方案。分析要有深度，建议要具体可执行。',
      sb.toString(),
    );
  }

  Future<String> coverAnalysis(List<Map<String, dynamic>> videos) async {
    if (videos.isEmpty) return '暂无视频数据';
    final sb = StringBuffer();
    sb.writeln('封面效果分析 - 共${videos.length}条视频');
    sb.writeln('');

    final withCoverCtr = videos.where((v) {
      final ctr = (v['cover_ctr'] as double?) ?? 0;
      return ctr > 0;
    }).toList();

    if (withCoverCtr.isEmpty) {
      return '暂无封面点击率数据，导入更多详细数据后可分析';
    }

    final sortedByCtr = List<Map<String, dynamic>>.from(withCoverCtr)
      ..sort((a, b) =>
          ((b['cover_ctr'] ?? 0).compareTo((a['cover_ctr'] ?? 0))));
    final topCover = sortedByCtr.take(5).toList();
    final bottomCover = sortedByCtr.length > 5
        ? sortedByCtr.sublist(sortedByCtr.length - 5)
        : <Map<String, dynamic>>[];

    final avgCtr = withCoverCtr.fold<double>(
            0, (s, v) => s + ((v['cover_ctr'] as double?) ?? 0)) /
        withCoverCtr.length;

    sb.writeln('平均封面点击率：${avgCtr.toStringAsFixed(1)}%');
    sb.writeln('有封面数据视频：${withCoverCtr.length}条');
    sb.writeln('');
    sb.writeln('【高封面点击率TOP5】');
    for (int i = 0; i < topCover.length; i++) {
      sb.writeln('${i + 1}. ${topCover[i]['title'] ?? ''} - CTR ${((topCover[i]['cover_ctr'] as double?) ?? 0).toStringAsFixed(1)}%');
    }
    sb.writeln('');
    if (bottomCover.isNotEmpty) {
      sb.writeln('【低封面点击率Bottom5】');
      for (int i = 0; i < bottomCover.length; i++) {
        sb.writeln('${i + 1}. ${bottomCover[i]['title'] ?? ''} - CTR ${((bottomCover[i]['cover_ctr'] as double?) ?? 0).toStringAsFixed(1)}%');
      }
      sb.writeln('');
    }

    sb.writeln('请输出封面优化分析报告：');
    sb.writeln('');
    sb.writeln('【封面效果诊断】');
    sb.writeln('当前封面整体表现评估，与行业基准对比');
    sb.writeln('');
    sb.writeln('【高CTR封面特征分析】');
    sb.writeln('分析高点击率封面可能具备的共性特征');
    sb.writeln('');
    sb.writeln('【封面优化方向】');
    sb.writeln('5个具体的封面优化建议，每条配示例说明');
    sb.writeln('');
    sb.writeln('【封面设计公式】');
    sb.writeln('提炼3种可复用的高点击率封面设计公式');
    sb.writeln('');
    sb.writeln('【封面避坑指南】');
    sb.writeln('5个常见的封面错误及避免方法');

    return chat(
      '你是抖音封面设计专家，深谙抖音流量推荐逻辑和用户点击心理，精通高点击率封面设计方法。建议要具体、可落地。',
      sb.toString(),
    );
  }

  Future<String> trafficSourceAnalysis(Map<String, dynamic> trafficData) async {
    final recommend = (trafficData['traffic_recommend'] as double?) ?? 0;
    final search = (trafficData['traffic_search'] as double?) ?? 0;
    final follow = (trafficData['traffic_follow'] as double?) ?? 0;
    final city = (trafficData['traffic_city'] as double?) ?? 0;

    if (recommend == 0 && search == 0 && follow == 0 && city == 0) {
      return '暂无流量来源数据，导入更多详细数据后可分析';
    }

    final total = recommend + search + follow + city;
    final sb = StringBuffer();
    sb.writeln('流量来源结构分析：');
    sb.writeln('');
    if (recommend > 0) sb.writeln('推荐流量：${recommend.toStringAsFixed(1)}% (${total > 0 ? (recommend / total * 100).toStringAsFixed(1) : 0}%)');
    if (search > 0) sb.writeln('搜索流量：${search.toStringAsFixed(1)}% (${total > 0 ? (search / total * 100).toStringAsFixed(1) : 0}%)');
    if (follow > 0) sb.writeln('关注流量：${follow.toStringAsFixed(1)}% (${total > 0 ? (follow / total * 100).toStringAsFixed(1) : 0}%)');
    if (city > 0) sb.writeln('同城流量：${city.toStringAsFixed(1)}% (${total > 0 ? (city / total * 100).toStringAsFixed(1) : 0}%)');
    sb.writeln('');
    sb.writeln('请输出流量来源分析与优化建议：');
    sb.writeln('');
    sb.writeln('【流量结构诊断】');
    sb.writeln('当前流量结构是否健康？各渠道占比是否合理？');
    sb.writeln('');
    sb.writeln('【各渠道优化建议】');
    sb.writeln('1. 推荐流量：如何提升推荐流量占比');
    sb.writeln('2. 搜索流量：如何布局搜索流量');
    sb.writeln('3. 关注流量：如何提升粉丝活跃度');
    sb.writeln('4. 同城流量：如何利用同城流量');
    sb.writeln('');
    sb.writeln('【流量增长策略】');
    sb.writeln('3条核心的流量增长策略，按优先级排序');

    return chat(
      '你是抖音流量运营专家，精通抖音流量分发机制、各流量渠道特点和优化方法。能够根据流量结构给出精准的增长策略建议。',
      sb.toString(),
    );
  }
}
