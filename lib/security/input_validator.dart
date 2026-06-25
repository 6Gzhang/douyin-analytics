/// 输入校验器 - 防止注入攻击和非法输入
class InputValidator {
  InputValidator._();

  // ---- 通用校验 ----

  /// 校验非空
  static String? required(String? value, [String label = '输入']) {
    if (value == null || value.trim().isEmpty) {
      return '$label 不能为空';
    }
    return null;
  }

  /// 校验长度范围
  static String? length(String? value, int min, int max, [String label = '输入']) {
    if (value == null) return '$label 不能为空';
    if (value.length < min) return '$label 至少需要 $min 个字符';
    if (value.length > max) return '$label 不能超过 $max 个字符';
    return null;
  }

  // ---- API Key 校验 ----

  /// 校验 API Key 格式
  static String? apiKey(String? value) {
    if (value == null || value.trim().isEmpty) return null; // 可选
    final trimmed = value.trim();
    if (trimmed.length < 16) return 'API Key 格式不正确（至少16个字符）';
    if (trimmed.length > 256) return 'API Key 长度超出限制';
    // 只允许字母数字和下划线
    if (!RegExp(r'^[a-zA-Z0-9_\-\.]+$').hasMatch(trimmed)) {
      return 'API Key 包含无效字符';
    }
    return null;
  }

  // ---- 文件名校验 ----

  /// 校验文件名（防止路径遍历攻击）
  static String? fileName(String? value) {
    if (value == null || value.trim().isEmpty) return '文件名不能为空';
    // 禁止路径分隔符
    if (value.contains('/') || value.contains('\\') || value.contains('..')) {
      return '文件名包含非法字符';
    }
    if (value.length > 255) return '文件名过长';
    return null;
  }

  // ---- URL 校验 ----

  /// 校验 URL（只允许 HTTPS）
  static String? httpsUrl(String? value) {
    if (value == null || value.trim().isEmpty) return 'URL 不能为空';
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return 'URL 格式不正确';
    if (uri.scheme != 'https') return '只允许 HTTPS 协议的 URL';
    if (uri.host.isEmpty) return 'URL 缺少主机名';
    return null;
  }

  // ---- 版本号校验 ----

  /// 校验版本号格式
  static String? version(String? value) {
    if (value == null || value.trim().isEmpty) return '版本号不能为空';
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value.trim())) {
      return '版本号格式应为 x.y.z（如 1.0.0）';
    }
    return null;
  }

  // ---- 文件路径校验 ----

  /// 校验文件路径（防止路径遍历）
  static String? filePath(String? value) {
    if (value == null || value.trim().isEmpty) return '文件路径不能为空';
    if (value.contains('..')) return '文件路径包含非法字符 ".."';
    return null;
  }

  // ---- 文本内容清洗 ----

  /// 清洗文本（移除危险字符，防止 XSS）
  static String sanitizeText(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('&', '&amp;');
  }

  /// 清洗 HTML 标签
  static String stripHtml(String input) {
    return input.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// 清洗 SQL 注入风险字符
  static String sanitizeSql(String input) {
    return input
        .replaceAll("'", "''")
        .replaceAll(';', '')
        .replaceAll('--', '')
        .replaceAll('/*', '')
        .replaceAll('*/', '');
  }

  // ---- 数字校验 ----

  /// 校验正整数
  static String? positiveInt(String? value, [String label = '数值']) {
    if (value == null || value.trim().isEmpty) return '$label 不能为空';
    final num = int.tryParse(value.trim());
    if (num == null) return '$label 必须是整数';
    if (num < 0) return '$label 不能为负数';
    return null;
  }

  /// 校验范围
  static String? intRange(String? value, int min, int max, [String label = '数值']) {
    final error = positiveInt(value, label);
    if (error != null) return error;
    final num = int.parse(value!.trim());
    if (num < min || num > max) return '$label 必须在 $min-$max 之间';
    return null;
  }

  // ---- 邮箱校验 ----

  /// 校验邮箱格式
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) return '邮箱格式不正确';
    return null;
  }
}