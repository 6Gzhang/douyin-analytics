import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全服务 - 提供加密、哈希、令牌生成等核心安全功能
class SecurityService {
  SecurityService._();
  static final SecurityService instance = SecurityService._();

  final _secureStorage = const FlutterSecureStorage();

  // ---- AES 加密/解密 ----

  static final _aesKey = enc.Key.fromSecureRandom(32);
  static final _aesIv = enc.IV.fromSecureRandom(16);

  /// 加密字符串
  String encrypt(String plainText) {
    final encrypter = enc.Encrypter(enc.AES(_aesKey));
    final encrypted = encrypter.encrypt(plainText, iv: _aesIv);
    return encrypted.base64;
  }

  /// 解密字符串
  String decrypt(String encryptedText) {
    try {
      final encrypter = enc.Encrypter(enc.AES(_aesKey));
      return encrypter.decrypt64(encryptedText, iv: _aesIv);
    } catch (_) {
      return '';
    }
  }

  /// 使用持久化密钥加密（Key 存储在 SecureStorage 中）
  Future<String> encryptPersistent(String plainText) async {
    final key = await _getOrCreateEncryptionKey();
    final encrypter = enc.Encrypter(enc.AES(enc.Key.fromBase64(key)));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    // 将 IV 拼接在密文前面（Base64）
    return '${iv.base64}:${encrypted.base64}';
  }

  /// 使用持久化密钥解密
  Future<String> decryptPersistent(String encryptedText) async {
    try {
      final key = await _getOrCreateEncryptionKey();
      final parts = encryptedText.split(':');
      if (parts.length != 2) return '';
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(enc.Key.fromBase64(key)));
      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (_) {
      return '';
    }
  }

  Future<String> _getOrCreateEncryptionKey() async {
    var key = await _secureStorage.read(key: '_encryption_key');
    if (key == null || key.length < 32) {
      key = enc.Key.fromSecureRandom(32).base64;
      await _secureStorage.write(key: '_encryption_key', value: key);
    }
    return key;
  }

  // ---- 哈希 ----

  /// SHA-256 哈希
  String sha256(String input) {
    return crypto.sha256.convert(utf8.encode(input)).toString();
  }

  /// HMAC-SHA256
  String hmacSha256(String input, String key) {
    final hmac = crypto.Hmac(crypto.sha256, utf8.encode(key));
    return hmac.convert(utf8.encode(input)).toString();
  }

  // ---- 安全随机 ----

  /// 生成安全随机令牌
  String generateToken({int length = 32}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// 生成安全随机 PIN
  String generatePin({int length = 6}) {
    final random = Random.secure();
    return List.generate(length, (_) => random.nextInt(10)).join();
  }

  // ---- 安全存储 ----

  /// 安全存储敏感数据
  Future<void> secureWrite(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  /// 安全读取敏感数据
  Future<String?> secureRead(String key) async {
    return await _secureStorage.read(key: key);
  }

  /// 安全删除敏感数据
  Future<void> secureDelete(String key) async {
    await _secureStorage.delete(key: key);
  }

  // ---- 数据脱敏 ----

  /// 脱敏手机号（显示前3后4）
  static String maskPhone(String phone) {
    if (phone.length < 7) return '****';
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  /// 脱敏 API Key（显示前4后4）
  static String maskApiKey(String key) {
    if (key.length < 10) return '****';
    return '${key.substring(0, 4)}****${key.substring(key.length - 4)}';
  }

  /// 脱敏邮箱
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return '****';
    final name = parts[0];
    if (name.length <= 2) return '**@${parts[1]}';
    return '${name[0]}***@${parts[1]}';
  }
}