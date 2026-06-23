import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/database/database.dart';
import '../../data_sources/csv_parser.dart';
import '../../services/ai_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _db = AppDatabase();
  bool _clearingCache = false;
  bool _importing = false;
  String _apiKey = '';
  String _selectedModel = SpKeys.defaultModel;
  int _aiUsageCount = 0;
  int _aiEstimatedTokens = 0;

  @override
  void initState() {
    super.initState();
    _loadAiConfig();
  }

  Future<void> _loadAiConfig() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = sp.getString(SpKeys.dashscopeApiKey) ?? '';
      _selectedModel = sp.getString(SpKeys.dashscopeModel) ?? SpKeys.defaultModel;
      _aiUsageCount = sp.getInt(SpKeys.aiUsageCount) ?? 0;
      _aiEstimatedTokens = sp.getInt(SpKeys.aiEstimatedTokens) ?? 0;
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
          _sectionHeader('功能说明'),
          const SizedBox(height: 8),
          _buildHelpCard(),
          const SizedBox(height: 24),
          _sectionHeader('关于'),
          const SizedBox(height: 8),
          _buildAboutCard(),
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
            color: AppTheme.accentBlue.withValues(alpha: 0.1),
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

  // ---- 清除缓存 ----
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
              title: const Text('阿里云百炼 API Key'),
              subtitle: Text(_apiKey.isNotEmpty
                  ? '${_apiKey.substring(0, 8)}****${_apiKey.length > 12 ? _apiKey.substring(_apiKey.length - 4) : ""}'
                  : '未设置',
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
                  DropdownMenuItem(value: 'qwen-turbo', child: Text('Turbo')),
                  DropdownMenuItem(value: 'qwen-plus', child: Text('Plus')),
                  DropdownMenuItem(value: 'qwen-max', child: Text('Max')),
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
          ],
        ),
      ),
    );
  }

  String _modelDisplayName() {
    switch (_selectedModel) {
      case 'qwen-turbo': return 'Qwen Turbo (轻量)';
      case 'qwen-plus': return 'Qwen Plus (推荐)';
      case 'qwen-max': return 'Qwen Max (最強)';
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
            labelText: '阿里云百炼 DashScope API Key',
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('保存')),
        ],
      ),
    );
    if (result != null && mounted) {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(SpKeys.dashscopeApiKey, result);
      AiService.instance.updateApiKey(result);
      setState(() => _apiKey = result);
    }
  }

  Future<void> _setModel(String model) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(SpKeys.dashscopeModel, model);
    AiService.instance.setModel(model);
    setState(() => _selectedModel = model);
  }

  Widget _buildClearCacheTile() {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.accentAmber.withValues(alpha: 0.1),
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
            color: AppTheme.douyinRed.withValues(alpha: 0.1),
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
              color: AppTheme.accentBlue.withValues(alpha: 0.1),
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

  Widget _buildAboutCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('douyin_analytics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('v1.3.0',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 12),
            Text(
              '本次更新：千问云端AI助手、智能API自适应、新字段补全(2秒跳出率/封面点击率/主页访问量)、AI视频诊断、发布日历分析、完播率深度分析、模拟观众反馈',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerCard() {
    return Card(
      color: AppTheme.douyinRed.withValues(alpha: 0.04),
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
