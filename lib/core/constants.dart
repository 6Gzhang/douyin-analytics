/// 应用常量
class AppConstants {
  AppConstants._();
  static const String appName = 'Douyin Analytics';
  static const String appVersion = '1.4.0';
  static const String appDescription = '抖音数据分析工具';

  // 抖音开放平台配置
  static const String douyinOAuthBaseUrl = 'https://open.douyin.com';
  static const String douyinApiBaseUrl = 'https://open.douyin.com';
  static const String douyinClientKey = '';
  static const String douyinClientSecret = '';
  static const String douyinRedirectUri = 'douyinanalytics://auth';
  static const List<String> oauthScopes = [
    'user_info',
    'video.list',
    'video.data',
    'fans.list',
    'fans.data',
  ];

  // OAuth 存储 Key
  static const String accessTokenKey = 'dy_access_token';
  static const String refreshTokenKey = 'dy_refresh_token';
  static const String openIdKey = 'dy_open_id';
  static const String expiresAtKey = 'dy_expires_at';
}

/// SharedPreferences keys
class SpKeys {
  SpKeys._();
  static const String themeMode = 'theme_mode';
  static const String hideTutorial = 'hide_tutorial';
  static const String dashscopeApiKey = 'dashscope_api_key';
  static const String dashscopeModel = 'dashscope_model';
  static const String aiUsageCount = 'ai_usage_count';
  static const String aiEstimatedTokens = 'ai_estimated_tokens';
  static const String defaultModel = 'qwen-plus';
}
