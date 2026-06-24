import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// 自动同步服务状态
class AutoSyncState {
  final bool isInstalled;
  final bool isConfigured;
  final bool isRunning;
  final DateTime? lastSyncTime;
  final String? syncTime;
  final String? status;
  final String? error;

  AutoSyncState({
    this.isInstalled = false,
    this.isConfigured = false,
    this.isRunning = false,
    this.lastSyncTime,
    this.syncTime,
    this.status,
    this.error,
  });

  AutoSyncState copyWith({
    bool? isInstalled,
    bool? isConfigured,
    bool? isRunning,
    DateTime? lastSyncTime,
    String? syncTime,
    String? status,
    String? error,
  }) {
    return AutoSyncState(
      isInstalled: isInstalled ?? this.isInstalled,
      isConfigured: isConfigured ?? this.isConfigured,
      isRunning: isRunning ?? this.isRunning,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncTime: syncTime ?? this.syncTime,
      status: status ?? this.status,
      error: error,
    );
  }
}

// 自动同步服务 Provider
final autoSyncProvider = StateNotifierProvider<AutoSyncNotifier, AutoSyncState>((ref) {
  return AutoSyncNotifier();
});

class AutoSyncNotifier extends StateNotifier<AutoSyncState> {
  AutoSyncNotifier() : super(AutoSyncState()) {
    checkStatus();
  }

  String? _autoSyncDir;

  Future<String> get autoSyncDir async {
    if (_autoSyncDir != null) return _autoSyncDir!;

    final homeDir = Platform.environment['HOME'] ?? '/Users/zhangdongsheng';
    final parentDir = Directory(p.join(homeDir, 'Desktop', 'douyin_analytics_source'));
    _autoSyncDir = p.join(parentDir.path, 'douyin-auto-sync');
    return _autoSyncDir!;
  }

  // 检查状态
  Future<void> checkStatus() async {
    try {
      final dir = await autoSyncDir;
      final configFile = File(p.join(dir, 'config', 'settings.json'));
      final syncInfoFile = File(p.join(dir, 'data', 'sync_info.json'));
      final packageFile = File(p.join(dir, 'package.json'));

      final isInstalled = await packageFile.exists();
      final isConfigured = await configFile.exists();

      DateTime? lastSync;
      String? syncTime;
      String? status;

      if (await syncInfoFile.exists()) {
        final info = jsonDecode(await syncInfoFile.readAsString());
        if (info['lastSyncTime'] != null) {
          lastSync = DateTime.fromMillisecondsSinceEpoch(info['lastSyncTime']);
        }
        status = info['status'];
      }

      if (await configFile.exists()) {
        final config = jsonDecode(await configFile.readAsString());
        syncTime = config['syncTime'];
      }

      state = state.copyWith(
        isInstalled: isInstalled,
        isConfigured: isConfigured,
        lastSyncTime: lastSync,
        syncTime: syncTime,
        status: status,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // 安装自动同步系统
  Future<bool> install() async {
    try {
      state = state.copyWith(status: 'installing');

      final dir = await autoSyncDir;
      final result = await Process.run('bash', ['-c', '''
        cd "$dir" && npm install
      '''], runInShell: true);

      if (result.exitCode == 0) {
        // 安装 Playwright 浏览器
        await Process.run('bash', ['-c', '''
          cd "$dir" && npx playwright install chromium
        '''], runInShell: true);

        await checkStatus();
        state = state.copyWith(status: 'installed');
        return true;
      } else {
        state = state.copyWith(status: 'failed', error: result.stderr.toString());
        return false;
      }
    } catch (e) {
      state = state.copyWith(status: 'failed', error: e.toString());
      return false;
    }
  }

  // 配置自动同步系统
  Future<bool> setup({
    required String phone,
    required String password,
    required String syncTime,
    String? gitRepo,
  }) async {
    try {
      state = state.copyWith(status: 'configuring');

      final dir = await autoSyncDir;
      final scriptFile = File(p.join(dir, 'scripts', 'setup.js'));

      if (!await scriptFile.exists()) {
        state = state.copyWith(status: 'failed', error: 'setup.js not found');
        return false;
      }

      // 创建临时配置脚本
      final setupScript = '''
const fs = require('fs');
const CryptoJS = require('crypto-js');
const path = require('path');

const BASE_DIR = '${dir.replaceAll("'", "'\"'\"'")}';
const CONFIG_DIR = path.join(BASE_DIR, 'config');
const DATA_DIR = path.join(BASE_DIR, 'data');

// 确保目录存在
fs.mkdirSync(CONFIG_DIR, { recursive: true });
fs.mkdirSync(DATA_DIR, { recursive: true });
fs.mkdirSync(path.join(DATA_DIR, 'downloads'), { recursive: true });

// 生成加密密钥
const encryptionKey = CryptoJS.lib.WordArray.random(16).toString();

// 加密凭证
const encrypted = CryptoJS.AES.encrypt(
  JSON.stringify({
    phone: '$phone',
    password: '$password'
  }),
  encryptionKey
).toString();

// 保存加密的凭证
fs.writeFileSync(path.join(CONFIG_DIR, 'credentials.enc'), encrypted);

// 保存设置
const settings = {
  encryptionKey: encryptionKey,
  syncTime: '$syncTime',
  downloadDir: path.join(DATA_DIR, 'downloads'),
  enableSync: ${gitRepo != null ? 'true' : 'false'},
  syncService: '${gitRepo != null ? 'git' : 'null'}',
  gitRepo: ${gitRepo != null ? "'$gitRepo'" : 'null'},
  deviceId: 'device_\${Date.now()}',
  createdAt: new Date().toISOString()
};

fs.writeFileSync(
  path.join(CONFIG_DIR, 'settings.json'),
  JSON.stringify(settings, null, 2)
);

// 初始化同步信息
const syncInfo = {
  lastSyncTime: null,
  lastSyncDate: null,
  status: 'configured',
  version: '1.0.0'
};
fs.writeFileSync(
  path.join(DATA_DIR, 'sync_info.json'),
  JSON.stringify(syncInfo, null, 2)
);

console.log('Configuration completed successfully!');
''';

      final tempScript = File(p.join(dir, 'setup_temp.js'));
      await tempScript.writeAsString(setupScript);

      final result = await Process.run(
        'node',
        [p.join(dir, 'setup_temp.js')],
        runInShell: true,
      );

      // 删除临时脚本
      await tempScript.delete();

      if (result.exitCode == 0) {
        await checkStatus();
        state = state.copyWith(
          status: 'configured',
          syncTime: syncTime,
        );
        return true;
      } else {
        state = state.copyWith(status: 'failed', error: result.stderr.toString());
        return false;
      }
    } catch (e) {
      state = state.copyWith(status: 'failed', error: e.toString());
      return false;
    }
  }

  // 手动触发同步
  Future<bool> triggerSync() async {
    try {
      state = state.copyWith(status: 'syncing');

      final dir = await autoSyncDir;
      final result = await Process.run(
        'node',
        [p.join(dir, 'scripts', 'douyin_scraper.js')],
        runInShell: true,
      );

      await checkStatus();

      if (result.exitCode == 0) {
        state = state.copyWith(status: 'success', lastSyncTime: DateTime.now());
        return true;
      } else {
        state = state.copyWith(status: 'failed', error: result.stderr.toString());
        return false;
      }
    } catch (e) {
      state = state.copyWith(status: 'failed', error: e.toString());
      return false;
    }
  }

  // 启动守护进程
  Future<bool> startDaemon() async {
    try {
      final dir = await autoSyncDir;

      // 检查是否有正在运行的进程
      final pidFile = File(p.join(dir, 'daemon.pid'));
      if (await pidFile.exists()) {
        final pid = (await pidFile.readAsString()).trim();
        try {
          Process.run('kill', ['-0', pid]);
          state = state.copyWith(isRunning: true);
          return true; // 已经在运行
        } catch (_) {
          // 进程不存在，继续启动
        }
      }

      // 启动守护进程
      final process = await Process.start(
        'node',
        [p.join(dir, 'scripts', 'scheduler.js')],
        runInShell: true,
      );

      // 保存PID
      await pidFile.writeAsString(process.pid.toString());

      state = state.copyWith(isRunning: true, status: 'running');
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // 停止守护进程
  Future<void> stopDaemon() async {
    try {
      final dir = await autoSyncDir;
      final pidFile = File(p.join(dir, 'daemon.pid'));

      if (await pidFile.exists()) {
        final pid = (await pidFile.readAsString()).trim();
        Process.killPid(int.parse(pid));
        await pidFile.delete();
      }

      state = state.copyWith(isRunning: false, status: 'stopped');
    } catch (_) {
      state = state.copyWith(isRunning: false);
    }
  }
}
