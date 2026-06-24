/// 视频质量分析工具
class VideoQualityAnalyzer {
  /// 计算视频综合质量评分 (0-100分)
  static double calculateQualityScore({
    required int playCount,
    required int likeCount,
    required int commentCount,
    required int shareCount,
    required int collectCount,
    required double finishRate,
    required double avgWatchDuration,
    required double fiveSecondFinishRate,
    required double twoSecondExitRate,
    required double coverCtr,
    required int newFollowers,
    required double duration,
  }) {
    if (playCount == 0) return 0;

    double totalScore = 0;
    double totalWeight = 0;

    // 1. 完播率 (权重: 25%)
    final finishScore = _normalize(finishRate, max: 0.8, min: 0.1) * 25;
    totalScore += finishScore;
    totalWeight += 25;

    // 2. 5秒完播率 (权重: 15%)
    final fiveSecScore = _normalize(fiveSecondFinishRate, max: 0.7, min: 0.2) * 15;
    totalScore += fiveSecScore;
    totalWeight += 15;

    // 3. 2秒跳出率 (反向，权重: 10%)
    final exitScore = (1 - _normalize(twoSecondExitRate, max: 0.6, min: 0.2)) * 10;
    totalScore += exitScore;
    totalWeight += 10;

    // 4. 互动率 (点赞+评论+分享+收藏，权重: 20%)
    final likeRate = playCount > 0 ? likeCount / playCount : 0.0;
    final commentRate = playCount > 0 ? commentCount / playCount : 0.0;
    final shareRate = playCount > 0 ? shareCount / playCount : 0.0;
    final collectRate = playCount > 0 ? collectCount / playCount : 0.0;

    final interactionScore = (
      _normalize(likeRate, max: 0.15, min: 0.02) * 0.4 +
      _normalize(commentRate, max: 0.03, min: 0.003) * 0.3 +
      _normalize(shareRate, max: 0.015, min: 0.002) * 0.2 +
      _normalize(collectRate, max: 0.02, min: 0.003) * 0.1
    ) * 20;
    totalScore += interactionScore;
    totalWeight += 20;

    // 5. 封面点击率 (权重: 10%)
    final ctrScore = _normalize(coverCtr, max: 0.25, min: 0.05) * 10;
    totalScore += ctrScore;
    totalWeight += 10;

    // 6. 涨粉效率 (权重: 10%)
    final followerRate = playCount > 0 ? newFollowers / playCount : 0.0;
    final followerScore = _normalize(followerRate, max: 0.01, min: 0.001) * 10;
    totalScore += followerScore;
    totalWeight += 10;

    // 7. 观看时长效率 (权重: 10%)
    final watchEfficiency = duration > 0 ? avgWatchDuration / duration : 0.0;
    final watchScore = _normalize(watchEfficiency, max: 0.9, min: 0.3) * 10;
    totalScore += watchScore;
    totalWeight += 10;

    return (totalScore / totalWeight) * 100;
  }

  /// 获取质量等级
  static QualityGrade getQualityGrade(double score) {
    if (score >= 85) return QualityGrade.s;
    if (score >= 75) return QualityGrade.a;
    if (score >= 60) return QualityGrade.b;
    if (score >= 45) return QualityGrade.c;
    return QualityGrade.d;
  }

  /// 获取等级文字
  static String getGradeText(QualityGrade grade) {
    switch (grade) {
      case QualityGrade.s: return 'S级 爆款';
      case QualityGrade.a: return 'A级 优秀';
      case QualityGrade.b: return 'B级 良好';
      case QualityGrade.c: return 'C级 一般';
      case QualityGrade.d: return 'D级 待优化';
    }
  }

  /// 获取等级颜色
  static int getGradeColor(QualityGrade grade) {
    switch (grade) {
      case QualityGrade.s: return 0xFFFF6B6B;
      case QualityGrade.a: return 0xFFFFD93D;
      case QualityGrade.b: return 0xFF6BCB77;
      case QualityGrade.c: return 0xFF4D96FF;
      case QualityGrade.d: return 0xFF868E96;
    }
  }

  /// 分析视频的强项和弱项
  static Map<String, dynamic> analyzeStrengthsWeaknesses({
    required int playCount,
    required int likeCount,
    required int commentCount,
    required int shareCount,
    required int collectCount,
    required double finishRate,
    required double avgWatchDuration,
    required double fiveSecondFinishRate,
    required double twoSecondExitRate,
    required double coverCtr,
    required int newFollowers,
    required double duration,
  }) {
    if (playCount == 0) {
      return {'strengths': <String>[], 'weaknesses': <String>[]};
    }

    final strengths = <String>[];
    final weaknesses = <String>[];

    final likeRate = likeCount / playCount;
    final commentRate = commentCount / playCount;
    final shareRate = shareCount / playCount;
    final collectRate = collectCount / playCount;

    // 完播率
    if (finishRate >= 0.5) {
      strengths.add('完播率优秀，观众看完意愿强');
    } else if (finishRate < 0.25) {
      weaknesses.add('完播率偏低，内容吸引力不足');
    }

    // 5秒完播率
    if (fiveSecondFinishRate >= 0.6) {
      strengths.add('开头吸引力强，5秒留存好');
    } else if (fiveSecondFinishRate < 0.35) {
      weaknesses.add('前5秒留不住人，开头需要优化');
    }

    // 2秒跳出率
    if (twoSecondExitRate <= 0.25) {
      strengths.add('2秒跳出率低，封面标题匹配度高');
    } else if (twoSecondExitRate > 0.45) {
      weaknesses.add('2秒跳出率高，封面或标题有问题');
    }

    // 点赞率
    if (likeRate >= 0.08) {
      strengths.add('点赞率高，内容认可度强');
    } else if (likeRate < 0.03) {
      weaknesses.add('点赞率偏低，内容共鸣感不足');
    }

    // 评论率
    if (commentRate >= 0.02) {
      strengths.add('评论率高，话题讨论性强');
    } else if (commentRate < 0.005) {
      weaknesses.add('评论率低，缺乏互动点');
    }

    // 分享率
    if (shareRate >= 0.01) {
      strengths.add('分享率高，内容传播性强');
    } else if (shareRate < 0.003) {
      weaknesses.add('分享率低，内容缺乏传播价值');
    }

    // 收藏率
    if (collectRate >= 0.015) {
      strengths.add('收藏率高，内容实用价值高');
    } else if (collectRate < 0.004) {
      weaknesses.add('收藏率低，内容实用性待提升');
    }

    // 封面CTR
    if (coverCtr >= 0.18) {
      strengths.add('封面点击率优秀，视觉吸引力强');
    } else if (coverCtr < 0.08) {
      weaknesses.add('封面点击率低，视觉吸引力不足');
    }

    // 涨粉效率
    final followerRate = newFollowers / playCount;
    if (followerRate >= 0.005) {
      strengths.add('涨粉效率高，账号价值感强');
    } else if (followerRate < 0.001) {
      weaknesses.add('涨粉效率低，账号吸引力不足');
    }

    return {'strengths': strengths, 'weaknesses': weaknesses};
  }

  /// 归一化值到 0-1
  static double _normalize(double value, {double max = 1, double min = 0}) {
    if (value >= max) return 1;
    if (value <= min) return 0;
    return (value - min) / (max - min);
  }

  /// 计算百分位排名
  static double calculatePercentile(List<double> values, double target) {
    if (values.isEmpty) return 0;
    values.sort();
    int index = values.indexWhere((v) => v >= target);
    if (index == -1) return 100;
    return (index / values.length) * 100;
  }

  /// 发布时间分析 - 统计各时段发布的视频平均播放量
  static Map<int, double> analyzePublishHourPerformance(List<Map<String, dynamic>> videos) {
    final hourStats = <int, List<int>>{};

    for (final video in videos) {
      final publishTime = video['create_time'] ?? video['publish_timestamp'];
      final playCount = video['play_count'] ?? 0;

      if (publishTime != null && playCount > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(
          publishTime is int ? publishTime : (publishTime as num).toInt(),
        );
        final hour = dt.hour;
        hourStats.putIfAbsent(hour, () => []);
        hourStats[hour]!.add(playCount);
      }
    }

    final result = <int, double>{};
    hourStats.forEach((hour, plays) {
      if (plays.isNotEmpty) {
        result[hour] = plays.reduce((a, b) => a + b) / plays.length;
      }
    });

    return result;
  }

  /// 发布星期分析
  static Map<int, double> analyzePublishWeekdayPerformance(List<Map<String, dynamic>> videos) {
    final weekdayStats = <int, List<int>>{};

    for (final video in videos) {
      final publishTime = video['create_time'] ?? video['publish_timestamp'];
      final playCount = video['play_count'] ?? 0;

      if (publishTime != null && playCount > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(
          publishTime is int ? publishTime : (publishTime as num).toInt(),
        );
        final weekday = dt.weekday;
        weekdayStats.putIfAbsent(weekday, () => []);
        weekdayStats[weekday]!.add(playCount);
      }
    }

    final result = <int, double>{};
    weekdayStats.forEach((day, plays) {
      if (plays.isNotEmpty) {
        result[day] = plays.reduce((a, b) => a + b) / plays.length;
      }
    });

    return result;
  }

  /// 视频时长分析
  static Map<String, double> analyzeDurationPerformance(List<Map<String, dynamic>> videos) {
    final categories = {
      '0-15s': <int>[0, 15],
      '15-30s': <int>[15, 30],
      '30-60s': <int>[30, 60],
      '1-3min': <int>[60, 180],
      '3min+': <int>[180, 99999],
    };

    final result = <String, double>{};

    categories.forEach((name, range) {
      final filtered = videos.where((v) {
        final duration = v['duration']?.toDouble() ?? 0;
        return duration >= range[0] && duration < range[1];
      }).toList();

      if (filtered.isNotEmpty) {
        final avgPlays = filtered.map((v) => v['play_count'] as int? ?? 0).reduce((a, b) => a + b) / filtered.length;
        result[name] = avgPlays;
      }
    });

    return result;
  }

  /// 计算增长率
  static double calculateGrowthRate(double current, double previous) {
    if (previous == 0) return 0;
    return (current - previous) / previous;
  }

  /// 格式化大数字
  static String formatLargeNumber(int num) {
    if (num >= 100000000) {
      return '${(num / 100000000).toStringAsFixed(1)}亿';
    } else if (num >= 10000) {
      return '${(num / 10000).toStringAsFixed(1)}万';
    }
    return num.toString();
  }

  /// 格式化百分比
  static String formatPercent(double value, {int decimals = 1}) {
    return '${(value * 100).toStringAsFixed(decimals)}%';
  }
}

enum QualityGrade { s, a, b, c, d }
