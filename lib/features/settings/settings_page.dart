import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../data_sources/csv_parser.dart';
import '../../security/security.dart';
import '../../services/ai_service.dart';
import '../../services/update_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _db = AppDatabase();
  final _secureStorage = const FlutterSecureStorage();
  bool _clearingCache = false;
  bool _importing = false;
  bool _checkingUpdate = false;
  bool _debugMode = false;
  String _debugVersion = '';
  late TextEditingController _debugVersionController;
  String _apiKey = '';
  String _selectedModel = SpKeys.defaultModel;
  int _aiUsageCount = 0;
  int _aiEstimatedTokens = 0;
  String _currentVersion = '1.1.0';
  bool _lockEnabled = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _debugVersionController = TextEditingController();
    _loadAiConfig();
    _loadVersion();
  }

  @override
  void dispose() {
    _debugVersionController.dispose();
    super.dispose();
  }

  Future<void> _loadAiConfig() async {
    final sp = await SharedPreferences.getInstance();
    final apiKey = await _secureStorage.read(key: 'siliconflow_api_key_secure');
    final model = await _secureStorage.read(key: 'siliconflow_model_secure');
    await AppLockManager.instance.init();
    final bio = await AppLockManager.instance.canUseBiometrics();
    setState(() {
      _apiKey = apiKey ?? '';
      _selectedModel = model ?? SpKeys.defaultModel;
      _aiUsageCount = sp.getInt(SpKeys.aiUsageCount) ?? 0;
      _aiEstimatedTokens = sp.getInt(SpKeys.aiEstimatedTokens) ?? 0;
      _lockEnabled = AppLockManager.instance.isLockEnabled;
      _bioEnabled = AppLockManager.instance.isBioEnabled && bio;
    });
  }

  Future<void> _loadVersion() async {
    final version = await UpdateService.getCurrentVersion();
    setState(() {
      _currentVersion = version;
      _debugVersion = version;
    });
  }

  void _toggleDebugMode() {
    setState(() {
      _debugMode = !_debugMode;
      if (!_debugMode) {
        _debugVersion = _currentVersion;
        _debugVersionController.text = _currentVersion;
      } else {
        // 开启调试模式时,默认设置为比当前版本低的版本号
        _debugVersion = '1.0.0';
        _debugVersionController.text = '1.0.0';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('数据管理'),
          const SizedBox(height: 8),
          _buildCsvImportTile(),
          const SizedBox(height: 8),
          _buildClearCacheTile(),
          const SizedBox(height: 8),
          _buildClearDataTile(),
          const SizedBox(height: 24),
          _sectionHeader('AI 助手配置'),
          const SizedBox(height: 8),
          _buildAiConfigSection(),
          const SizedBox(height: 24),
          _sectionHeader('安全设置'),
          const SizedBox(height: 8),
          _buildSecuritySection(),
          const SizedBox(height: 16),
          _buildAutoSyncTile(),
          const SizedBox(height: 24),
          _sectionHeader('功能说明'),
          const SizedBox(height: 8),
          _buildHelpCard(),
          const SizedBox(height: 24),
          _sectionHeader('关于'),
          const SizedBox(height: 8),
          _buildAboutCard(),
          const SizedBox(height: 24),
          _sectionHeader('开发者'),
          const SizedBox(height: 8),
          _buildTechShowcaseTile(),
          const SizedBox(height: 24),
          _sectionHeader('危险区域'),
          const SizedBox(height: 8),
          _buildDangerCard(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500])),
    );
  }

  // ---- CSV 导入 ----
  Widget _buildCsvImportTile() {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.upload_file, color: AppTheme.accentBlue, size: 20),
        ),
        title: const Text('CSV 数据导入',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text('从抖音创作者中心导出的 CSV',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: _importing
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: _importing ? null : _importCsv,
      ),
    );
  }

  Future<void> _importCsv() async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _importing = false);
        return;
      }
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content);
      final metrics = CsvParser.parseDouyinDataEnhanced(rows);

      int imported = 0, skipped = 0;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (final m in metrics) {
        try {
          final title = (m['title'] as String?) ?? '';
          final createTime = (m['create_time'] as int?) ?? now;
          final videoId = 'csv_${createTime}_${now}_${imported + 1}';
          await _db.upsertVideo(
            id: videoId,
            title: title,
            createTime: createTime > 0 ? createTime : now,
            source: 'csv',
            sourceId: result.files.single.name,
          );
          await _db.upsertMetrics(
            videoId: videoId,
            playCount: (m['play_count'] as int?) ?? 0,
            likeCount: (m['like_count'] as int?) ?? 0,
            commentCount: (m['comment_count'] as int?) ?? 0,
            shareCount: (m['share_count'] as int?) ?? 0,
            collectCount: (m['collect_count'] as int?) ?? 0,
            finishRate: (m['finish_rate'] as double?),
            avgWatchDuration: (m['avg_watch_duration'] as double?),
            twoSecondExitRate: (m['two_second_exit_rate'] as double?),
            coverCtr: (m['cover_ctr'] as double?),
            profileVisits: (m['profile_visits'] as int?),
            fullPlayCount: (m['full_play_count'] as int?),
            fiveSecondFinishRate: (m['five_second_finish_rate'] as double?),
            fetchedAt: now,
            source: 'csv',
          );
          imported++;
        } catch (_) {
          skipped++;
        }
      }

      await _db.insertCsvImport({
        'file_name': result.files.single.name,
        'file_path': result.files.single.path!,
        'row_count': metrics.length,
        'imported_count': imported,
        'skipped_count': skipped,
        'imported_at': now,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功导入 $imported 条，跳过 $skipped 条'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败: $e'),
          backgroundColor: AppTheme.douyinRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  // ---- AI 配置 ----
  Widget _buildAiConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API Key
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('硅基流动 API Key'),
              subtitle: Text(_apiKey.isNotEmpty
                  ? '${_apiKey.substring(0, 8)}****${_apiKey.length > 12 ? _apiKey.substring(_apiKey.length - 4) : ""}'
                  : '未设置（免费使用 Qwen2.5-7B）',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              trailing: TextButton(
                onPressed: _editApiKey,
                child: Text(_apiKey.isNotEmpty ? '修改' : '设置'),
              ),
            ),
            // Model
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI 模型'),
              subtitle: Text(_modelDisplayName(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              trailing: DropdownButton<String>(
                value: _selectedModel,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'Qwen/Qwen2.5-7B-Instruct', child: Text('Qwen 2.5 7B (免费)')),
                  DropdownMenuItem(value: 'Qwen/Qwen2.5-14B-Instruct', child: Text('Qwen 2.5 14B')),
                  DropdownMenuItem(value: 'Qwen/Qwen2.5-72B-Instruct', child: Text('Qwen 2.5 72B')),
                ],
                onChanged: (v) {
                  if (v != null) _setModel(v);
                },
              ),
            ),
            // Usage stats
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.bar_chart, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text('AI 用量统计: 累计 $_aiUsageCount 次调用，约 $_aiEstimatedTokens tokens',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text('免费模型 Qwen2.5-7B 永久免费，注册送积分',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  String _modelDisplayName() {
    switch (_selectedModel) {
      case 'Qwen/Qwen2.5-7B-Instruct': return 'Qwen 2.5 7B (免费)';
      case 'Qwen/Qwen2.5-14B-Instruct': return 'Qwen 2.5 14B';
      case 'Qwen/Qwen2.5-72B-Instruct': return 'Qwen 2.5 72B';
      default: return _selectedModel;
    }
  }

  Future<void> _editApiKey() async {
    final ctrl = TextEditingController(text: _apiKey);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置 API Key'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'sk-xxxxxxxxxxxxxxxx',
            labelText: '硅基流动 SiliconFlow API Key',
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final error = InputValidator.apiKey(ctrl.text);
              if (error != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: AppTheme.douyinRed),
                );
                return;
              }
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await _secureStorage.write(key: 'siliconflow_api_key_secure', value: result);
      AiService.instance.updateApiKey(result);
      setState(() => _apiKey = result);
    }
  }

  Future<void> _setModel(String model) async {
    await _secureStorage.write(key: 'siliconflow_model_secure', value: model);
    AiService.instance.setModel(model);
    setState(() => _selectedModel = model);
  }

  // ---- 安全设置 ----
  Widget _buildSecuritySection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _lockEnabled,
              title: const Text('应用锁', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('启用 PIN 码锁屏保护数据安全'),
              secondary: const Icon(Icons.lock_outline),
              onChanged: (v) async {
                if (v) {
                  await _showSetPinDialog();
                } else {
                  await AppLockManager.instance.removePin();
                  setState(() => _lockEnabled = false);
                }
              },
            ),
            if (_lockEnabled) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('修改 PIN 码'),
                leading: const Icon(Icons.edit),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showSetPinDialog,
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _bioEnabled,
                title: const Text('生物识别'),
                subtitle: const Text('使用指纹或面容快速解锁'),
                secondary: const Icon(Icons.fingerprint),
                onChanged: _bioEnabled
                    ? (v) async {
                        await AppLockManager.instance.setBioEnabled(v);
                        setState(() => _bioEnabled = v);
                      }
                    : null,
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('自动锁屏时间'),
                subtitle: const Text('5 分钟'),
                leading: const Icon(Icons.timer),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // 可扩展为选择时间
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showSetPinDialog() async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置 PIN 码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinCtrl,
              obscureText: true,
              maxLength: 8,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN 码（4-8位数字）',
                hintText: '请输入 PIN 码',
              ),
              onChanged: (_) {
                if (ctx is StatefulElement) {
                  (ctx as dynamic).markNeedsBuild?.call();
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              maxLength: 8,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '确认 PIN 码',
                hintText: '请再次输入 PIN 码',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final pin = pinCtrl.text.trim();
              final confirm = confirmCtrl.text.trim();
              if (pin.length < 4 || pin.length > 8) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('PIN 码必须为 4-8 位数字'),
                    backgroundColor: AppTheme.douyinRed,
                  ),
                );
                return;
              }
              if (!RegExp(r'^\d+$').hasMatch(pin)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('PIN 码只能包含数字'),
                    backgroundColor: AppTheme.douyinRed,
                  ),
                );
                return;
              }
              if (pin != confirm) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('两次输入的 PIN 码不一致'),
                    backgroundColor: AppTheme.douyinRed,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, pin);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      final success = await AppLockManager.instance.setPin(result);
      if (success) {
        final bio = await AppLockManager.instance.canUseBiometrics();
        setState(() {
          _lockEnabled = true;
          _bioEnabled = bio;
        });
        if (bio) {
          await AppLockManager.instance.setBioEnabled(true);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN 码设置成功')), 
          );
        }
      }
    }
  }

  // ---- 自动同步 ----
  Widget _buildAutoSyncTile() {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.accentPink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.sync, color: AppTheme.accentPink, size: 20),
        ),
        title: const Text('自动数据同步', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text('每天自动登录抖音后台导出数据',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => context.go('/settings/auto-sync'),
      ),
    );
  }

  Widget _buildClearCacheTile() {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.accentAmber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.cleaning_services, color: AppTheme.accentAmber, size: 20),
        ),
        title: const Text('清除缓存',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text('清除飞书 Token 缓存，保留配置信息',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: _clearingCache
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: _clearingCache ? null : _clearCache,
      ),
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('将清除飞书 Token 缓存，保留 App ID/Secret/TableId 等配置。是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _clearingCache = true);
    try {
      await _db.clearFeishuCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('缓存已清除'), backgroundColor: AppTheme.accentGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e'), backgroundColor: AppTheme.douyinRed),
      );
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  // ---- 清除所有数据 ----
  Widget _buildClearDataTile() {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.douyinRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.delete_forever, color: AppTheme.douyinRed, size: 20),
        ),
        title: const Text('清除所有数据',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text('删除所有视频数据和配置',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: _clearAllData,
      ),
    );
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除所有数据'),
        content: const Text('此操作将删除所有视频数据和配置信息，不可恢复。是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.douyinRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _db.clearAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('所有数据已清除'), backgroundColor: AppTheme.accentGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e'), backgroundColor: AppTheme.douyinRed),
      );
    }
  }

  Widget _buildHelpCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, size: 20, color: AppTheme.accentBlue),
                const SizedBox(width: 8),
                const Text('快速上手',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            _helpRow('1', '在设置页点击「CSV 数据导入」'),
            _helpRow('2', '选择从抖音创作者中心导出的 CSV 文件'),
            _helpRow('3', '在概览页查看数据总览'),
            _helpRow('4', '在分析报告页查看详细报告'),
          ],
        ),
      ),
    );
  }

  Widget _helpRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(num,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentBlue)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildTechShowcaseTile() {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF00D4FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.rocket_launch,
              color: Color(0xFF00D4FF), size: 20),
        ),
        title: const Text('技术展示',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text('科技风 UI 展示页',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => context.go('/tech-showcase'),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('douyin_analytics',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'v$_currentVersion',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // 调试模式开关
            Row(
              children: [
                Switch(
                  value: _debugMode,
                  onChanged: (value) => _toggleDebugMode(),
                  activeColor: AppTheme.douyinRed,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('调试模式',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    Text('模拟旧版本以测试更新推送',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
            if (_debugMode) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _debugVersionController,
                decoration: InputDecoration(
                  labelText: '测试版本号',
                  hintText: '例如: 1.0.0',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (value) {
                  setState(() {
                    _debugVersion = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                '提示: 输入比当前版本低的版本号，点击“检查更新”即可看到更新提示',
                style: TextStyle(fontSize: 11, color: Colors.orange[700]),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('检查更新',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text('从 GitHub 获取最新版本',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                _checkingUpdate
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 测试按钮 - 模拟旧版本
                          FilledButton(
                            onPressed: () async {
                              setState(() => _checkingUpdate = true);
                              try {
                                final latest = await UpdateService.checkForUpdate('1.0.0');
                                if (!mounted) return;
                                if (latest != null) {
                                  _showUpdateDialog(latest);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('未检测到更新(GitHub上可能没有更高版本)'),
                                      backgroundColor: AppTheme.accentGreen,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('测试失败: $e'),
                                    backgroundColor: AppTheme.douyinRed,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              } finally {
                                if (mounted) setState(() => _checkingUpdate = false);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.douyinRed,
                            ),
                            child: const Text('🧪 测试'),
                          ),
                          const SizedBox(width: 8),
                          // 正常检查更新按钮
                          FilledButton.tonal(
                            onPressed: _checkUpdate,
                            child: const Text('检查更新'),
                          ),
                        ],
                      ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '数据驱动创作，每一条视频都值得被认真分析。',
              style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    try {
      final testVersion = _debugMode && _debugVersion.isNotEmpty ? _debugVersion : null;
      final latest = await UpdateService.checkForUpdate(testVersion);
      if (!mounted) return;
      if (latest != null) {
        _showUpdateDialog(latest);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前已是最新版本'),
            backgroundColor: AppTheme.accentGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('检查更新失败: $e'),
          backgroundColor: AppTheme.douyinRed,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _showUpdateDialog(AppVersion version) {
    final isDownloadable = version.downloadUrl != null &&
        version.downloadUrl!.endsWith('.dmg');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.update, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 8),
            const Text('发现新版本'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最新版本: v${version.version}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (version.releaseNotes != null && version.releaseNotes!.isNotEmpty) ...[
              const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    version.releaseNotes!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说'),
          ),
          if (isDownloadable)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _downloadAndInstall(version);
              },
              child: const Text('立即更新'),
            )
          else
            FilledButton(
              onPressed: () async {
                final url = version.downloadUrl ??
                    'https://github.com/6Gzhang/-/releases/latest';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('前往下载'),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(AppVersion version) async {
    double progress = 0;
    String? error;
    bool done = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (!done && error == null) {
              // 启动下载
              _startDownload(version, (p) {
                setDialogState(() => progress = p);
              }, (e) {
                setDialogState(() => error = e.toString());
              }, () {
                setDialogState(() => done = true);
              });
            }

            if (error != null) {
              return AlertDialog(
                title: const Text('下载失败'),
                content: Text(error!),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('确定'),
                  ),
                ],
              );
            }

            if (done) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 22),
                    const SizedBox(width: 8),
                    const Text('下载完成'),
                  ],
                ),
                content: const Text('安装包已下载，请在打开的窗口中拖拽应用到 Applications 文件夹即可完成安装。'),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('知道了'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('正在下载更新...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 12),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _startDownload(
    AppVersion version,
    void Function(double) onProgress,
    void Function(String) onError,
    void Function() onDone,
  ) async {
    try {
      final url = version.downloadUrl!;
      final filePath = await UpdateService.downloadUpdate(
        url,
        onProgress: onProgress,
      );
      await UpdateService.openInstaller(filePath);
      onDone();
    } catch (e) {
      onError(e.toString());
    }
  }

  Widget _buildDangerCard() {
    return Card(
      color: AppTheme.douyinRed.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, size: 18, color: AppTheme.douyinRed),
                const SizedBox(width: 8),
                const Text('危险区域',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.douyinRed)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '此区域的操作不可撤销，请谨慎使用。清除所有数据将删除全部视频记录和配置信息。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
