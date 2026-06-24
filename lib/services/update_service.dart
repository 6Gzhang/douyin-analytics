import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class AppVersion {
  final String version;
  final String? downloadUrl;
  final String? releaseNotes;
  final DateTime? publishedAt;

  AppVersion({
    required this.version,
    this.downloadUrl,
    this.releaseNotes,
    this.publishedAt,
  });

  bool isNewerThan(String currentVersion) {
    final current = _parseVersion(currentVersion);
    final latest = _parseVersion(version);
    if (current == null || latest == null) return false;
    for (int i = 0; i < 3; i++) {
      if (latest[i] > current[i]) return true;
      if (latest[i] < current[i]) return false;
    }
    return false;
  }

  List<int>? _parseVersion(String v) {
    try {
      final cleaned = v.replaceAll('v', '').split('+').first;
      final parts = cleaned.split('.').map(int.parse).toList();
      while (parts.length < 3) {
        parts.add(0);
      }
      return parts.sublist(0, 3);
    } catch (_) {
      return null;
    }
  }
}

class UpdateService {
  static const String repoOwner = '6Gzhang';
  static const String repoName = 'douyin-analytics';
  static const String apiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  static Future<String> getCurrentVersion() async {
    try {
      final manifestContent = await rootBundle.loadString('pubspec.yaml');
      final lines = manifestContent.split('\n');
      for (final line in lines) {
        if (line.startsWith('version:')) {
          return line.substring(9).trim();
        }
      }
    } catch (e) {
      print('读取版本号失败: $e');
    }
    return '1.1.0';
  }

  static Future<AppVersion?> checkForUpdate([String? currentVersion]) async {
    try {
      final version = currentVersion ?? await getCurrentVersion();
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String?;
      if (tagName == null) return null;

      final latestVersion = tagName.replaceAll('v', '');
      final appVersion = AppVersion(
        version: latestVersion,
        downloadUrl: _findDownloadUrl(data),
        releaseNotes: data['body'] as String?,
        publishedAt: data['published_at'] != null
            ? DateTime.tryParse(data['published_at'] as String)
            : null,
      );

      if (appVersion.isNewerThan(version)) {
        return appVersion;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String? _findDownloadUrl(Map<String, dynamic> data) {
    final assets = data['assets'] as List<dynamic>?;
    if (assets == null || assets.isEmpty) {
      return data['html_url'] as String?;
    }

    for (final asset in assets) {
      final name = (asset['name'] as String).toLowerCase();
      if (Platform.isMacOS && (name.contains('.dmg') || name.contains('macos'))) {
        return asset['browser_download_url'] as String?;
      }
    }

    return data['html_url'] as String?;
  }
}
