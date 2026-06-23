import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/database/database.dart';
import '../../data_sources/csv_parser.dart';

class DataImportPage extends ConsumerStatefulWidget {
  const DataImportPage({super.key});

  @override
  ConsumerState<DataImportPage> createState() => _DataImportPageState();
}

class _DataImportPageState extends ConsumerState<DataImportPage> {
  final _db = AppDatabase();
  bool _importing = false;
  String? _status;
  String? _pickedPath;
  String? _pickedName;
  List<List<dynamic>>? _previewRows;
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final list = await _db.getCsvImportHistory();
      if (!mounted) return;
      setState(() {
        _history = list;
        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      final fileName = result.files.single.name;
      if (filePath == null) return;

      final file = File(filePath);
      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content);

      if (!mounted) return;
      setState(() {
        _pickedPath = filePath;
        _pickedName = fileName;
        _previewRows = rows;
        _status = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '文件读取失败: $e';
        _pickedPath = null;
        _pickedName = null;
        _previewRows = null;
      });
    }
  }

  Future<void> _confirmImport() async {
    if (_previewRows == null || _pickedPath == null) return;

    setState(() {
      _importing = true;
      _status = '正在导入...';
    });

    try {
      final parsed = CsvParser.parseDouyinData(_previewRows!);
      int imported = 0;
      int skipped = 0;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      for (final metric in parsed) {
        try {
          final videoId = '${DateTime.now().microsecondsSinceEpoch
              .toString()
              .substring(0, 13)}_${imported + 1}';
          await _db.insertVideo({
            'id': videoId,
            'title': metric.videoTitle,
            'cover_url': '',
            'create_time': now,
            'is_top': 0,
            'source': 'csv',
            'source_id': _pickedPath!.split('/').last,
          });
          await _db.upsertVideoMetrics({
            'video_id': videoId,
            'play_count': metric.playCount,
            'like_count': metric.likeCount,
            'comment_count': metric.commentCount,
            'share_count': metric.shareCount,
            'collect_count': metric.collectCount,
            'finish_rate': metric.finishRate ?? 0,
            'avg_watch_duration': metric.avgWatchDuration ?? 0,
            'updated_at': now,
          });
          imported++;
        } catch (_) {
          skipped++;
        }
      }

      await _db.insertCsvImport({
        'file_name': _pickedName,
        'file_path': _pickedPath,
        'row_count': _previewRows!.length - 1,
        'imported_count': imported,
        'skipped_count': skipped,
        'imported_at': now,
      });

      await _loadHistory();
      if (!mounted) return;
      setState(() {
        _importing = false;
        _status = '导入完成：成功 $imported 条，跳过 $skipped 条';
      });

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) context.pop();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _status = '导入失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据导入'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGuidanceCard(),
          const SizedBox(height: 16),
          _buildImportCard(),
          const SizedBox(height: 16),
          if (_status != null) _buildStatusCard(),
          const SizedBox(height: 16),
          _buildHistorySection(),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard() {
    return Card(
      color: const Color(0xFFFFF8E7),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.withValues(alpha: 0.31)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 18),
                SizedBox(width: 6),
                Text('CSV 导出指引',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),
            _stepRow('1', '打开', 'creator.douyin.com', Icons.language),
            const SizedBox(height: 10),
            _stepRow('2', '进入', '内容管理 → 视频管理', Icons.video_library),
            const SizedBox(height: 10),
            _stepRow('3', '点击', '「导出」选择时间范围下载 CSV', Icons.download),
            const SizedBox(height: 10),
            _stepRow('4', '回到', '本 APP，点击下方按钮导入', Icons.phone_android),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(String num, String action, String target, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(num,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber)),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              children: [
                TextSpan(
                    text: '$action ',
                    style: TextStyle(color: Colors.grey[500])),
                TextSpan(
                    text: target,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportCard() {
    // 已选择文件时显示预览 + 确认按钮
    if (_previewRows != null) {
      final header = _previewRows!.isNotEmpty
          ? _previewRows!.first.map((c) => '$c').toList()
          : <String>[];
      final dataRows = _previewRows!.length > 1
          ? _previewRows!.skip(1).take(5).toList()
          : <List<dynamic>>[];
      final totalRows = _previewRows!.length - 1;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_pickedName ?? '已选择文件',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: _pickFile,
                    child: const Text('重新选择', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('共 $totalRows 条数据，预览前 ${dataRows.length} 条',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 8),
              // 表头 + 数据预览
              if (header.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 32,
                    dataRowMinHeight: 28,
                    dataRowMaxHeight: 36,
                    columnSpacing: 16,
                    horizontalMargin: 8,
                    columns: header
                        .map((h) => DataColumn(
                              label: Text(h,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey)),
                            ))
                        .toList(),
                    rows: dataRows
                        .map((row) => DataRow(
                              cells: row
                                  .map((cell) => DataCell(
                                        Text('$cell',
                                            style: const TextStyle(
                                                fontSize: 11),
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                            ))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: _importing ? null : _confirmImport,
                  icon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(_importing ? '导入中...' : '确认导入'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 未选择文件时显示选择按钮
    return Card(
      child: InkWell(
        onTap: _pickFile,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFE2C55).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.upload_file,
                    size: 32, color: Color(0xFFFE2C55)),
              ),
              const SizedBox(height: 16),
              const Text('点击选择 CSV 文件',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('支持抖音创作者中心导出的 CSV 格式',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isError =
        _status!.startsWith('导入失败') || _status!.contains('读取失败');
    final isSuccess = _status!.startsWith('导入完成');
    return Card(
      color: isError
          ? Colors.red.withValues(alpha: 0.06)
          : isSuccess
              ? Colors.green.withValues(alpha: 0.06)
              : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error
                  : isSuccess
                      ? Icons.check_circle
                      : Icons.hourglass_top,
              color: isError
                  ? Colors.red
                  : isSuccess
                      ? Colors.green
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_status!)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('导入历史',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_loadingHistory)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ))
        else if (_history.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('暂无导入记录',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
          )
        else
          ..._history.map((h) {
            final fileName = h['file_name'] ?? '未知文件';
            final imported = h['imported_count'] ?? 0;
            final skipped = h['skipped_count'] ?? 0;
            final ts = h['imported_at'] as int?;
            final date = ts != null
                ? DateTime.fromMillisecondsSinceEpoch(ts * 1000)
                    .toString()
                    .substring(0, 16)
                : '--';
            return Card(
              child: ListTile(
                leading: const Icon(Icons.description, color: Colors.green),
                title: Text(fileName, style: const TextStyle(fontSize: 14)),
                subtitle: Text('$date  成功 $imported / 跳过 $skipped',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ),
            );
          }),
      ],
    );
  }
}
