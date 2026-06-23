import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

/// 抖音开放平台 API 封装
class DouyinApi {
  final String accessToken;
  final http.Client _client = http.Client();

  DouyinApi({required this.accessToken});

  // ========== 视频列表 ==========

  /// 获取用户视频列表
  Future<DouyinVideoListResponse> getVideoList({
    int cursor = 0,
    int count = 20,
  }) async {
    final response = await _client.get(
      Uri.parse('${AppConstants.douyinApiBaseUrl}/video/list/')
          .replace(queryParameters: {
        'open_id': AppConstants.openIdKey, // 需要运行时替换
        'access_token': accessToken,
        'cursor': cursor.toString(),
        'count': count.toString(),
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return DouyinVideoListResponse.fromJson(jsonDecode(response.body));
    }
    throw DouyinApiException(response.statusCode, response.body);
  }

  // ========== 视频数据 ==========

  /// 批量获取视频数据
  Future<DouyinVideoDataResponse> getVideoData(List<String> itemIds) async {
    final response = await _client.post(
      Uri.parse('${AppConstants.douyinApiBaseUrl}/video/data/')
          .replace(queryParameters: {
        'open_id': 'open_id', // 需要运行时替换
        'access_token': accessToken,
      }),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'item_ids': itemIds.take(10).toList()}),
    );

    if (response.statusCode == 200) {
      return DouyinVideoDataResponse.fromJson(jsonDecode(response.body));
    }
    throw DouyinApiException(response.statusCode, response.body);
  }

  // ========== 账号数据 ==========

  /// 获取用户整体数据（近30天）
  Future<DouyinUserDataResponse> getUserData() async {
    final response = await _client.get(
      Uri.parse('${AppConstants.douyinApiBaseUrl}/data/external/user/')
          .replace(queryParameters: {
        'open_id': 'open_id',
        'access_token': accessToken,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return DouyinUserDataResponse.fromJson(jsonDecode(response.body));
    }
    throw DouyinApiException(response.statusCode, response.body);
  }

  // ========== 评论数据 ==========

  /// 获取视频评论列表
  Future<DouyinCommentListResponse> getComments(String itemId, {
    int cursor = 0,
    int count = 20,
  }) async {
    final response = await _client.get(
      Uri.parse('${AppConstants.douyinApiBaseUrl}/item/comment/list/')
          .replace(queryParameters: {
        'open_id': 'open_id',
        'access_token': accessToken,
        'item_id': itemId,
        'cursor': cursor.toString(),
        'count': count.toString(),
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return DouyinCommentListResponse.fromJson(jsonDecode(response.body));
    }
    throw DouyinApiException(response.statusCode, response.body);
  }

  void dispose() => _client.close();
}

// ========== 响应模型 ==========

class DouyinVideoListResponse {
  final List<DouyinVideoItem> list;
  final int cursor;
  final bool hasMore;

  DouyinVideoListResponse({
    required this.list,
    required this.cursor,
    required this.hasMore,
  });

  factory DouyinVideoListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final items = (data['list'] as List? ?? [])
        .map((e) => DouyinVideoItem.fromJson(e))
        .toList();
    return DouyinVideoListResponse(
      list: items,
      cursor: data['cursor'] ?? 0,
      hasMore: data['has_more'] ?? false,
    );
  }
}

class DouyinVideoItem {
  final String itemId;
  final String title;
  final String? cover;
  final int createTime;
  final bool isTop;

  DouyinVideoItem({
    required this.itemId,
    required this.title,
    this.cover,
    required this.createTime,
    this.isTop = false,
  });

  factory DouyinVideoItem.fromJson(Map<String, dynamic> json) {
    return DouyinVideoItem(
      itemId: json['item_id']?.toString() ?? '',
      title: json['title'] ?? '',
      cover: json['cover']?['url_list']?.first,
      createTime: json['create_time'] ?? 0,
      isTop: json['is_top'] ?? false,
    );
  }
}

class DouyinVideoDataResponse {
  final List<DouyinVideoStat> items;

  DouyinVideoDataResponse({required this.items});

  factory DouyinVideoDataResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final items = (data['list'] as List? ?? [])
        .map((e) => DouyinVideoStat.fromJson(e))
        .toList();
    return DouyinVideoDataResponse(items: items);
  }
}

class DouyinVideoStat {
  final String itemId;
  final int playCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int downloadCount;

  DouyinVideoStat({
    required this.itemId,
    required this.playCount,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.downloadCount,
  });

  factory DouyinVideoStat.fromJson(Map<String, dynamic> json) {
    final stat = json['statistics'] ?? {};
    return DouyinVideoStat(
      itemId: json['item_id']?.toString() ?? '',
      playCount: stat['play_count'] ?? 0,
      likeCount: stat['digg_count'] ?? 0,
      commentCount: stat['comment_count'] ?? 0,
      shareCount: stat['share_count'] ?? 0,
      downloadCount: stat['download_count'] ?? 0,
    );
  }
}

class DouyinUserDataResponse {
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int followerCount;
  final int homePageVisit;

  DouyinUserDataResponse({
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.followerCount,
    required this.homePageVisit,
  });

  factory DouyinUserDataResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    return DouyinUserDataResponse(
      likeCount: data['like_count'] ?? 0,
      commentCount: data['comment_count'] ?? 0,
      shareCount: data['share_count'] ?? 0,
      followerCount: data['follower_count'] ?? 0,
      homePageVisit: data['home_page_visit'] ?? 0,
    );
  }
}

class DouyinCommentListResponse {
  final List<DouyinComment> list;
  final int cursor;
  final bool hasMore;

  DouyinCommentListResponse({
    required this.list,
    required this.cursor,
    required this.hasMore,
  });

  factory DouyinCommentListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final items = (data['list'] as List? ?? [])
        .map((e) => DouyinComment.fromJson(e))
        .toList();
    return DouyinCommentListResponse(
      list: items,
      cursor: data['cursor'] ?? 0,
      hasMore: data['has_more'] ?? false,
    );
  }
}

class DouyinComment {
  final String commentId;
  final String content;
  final int likeCount;
  final int createTime;

  DouyinComment({
    required this.commentId,
    required this.content,
    required this.likeCount,
    required this.createTime,
  });

  factory DouyinComment.fromJson(Map<String, dynamic> json) {
    return DouyinComment(
      commentId: json['comment_id']?.toString() ?? '',
      content: json['content'] ?? '',
      likeCount: json['digg_count'] ?? 0,
      createTime: json['create_time'] ?? 0,
    );
  }
}

class DouyinApiException implements Exception {
  final int statusCode;
  final String body;

  DouyinApiException(this.statusCode, this.body);

  @override
  String toString() => 'DouyinApiException($statusCode): $body';
}
