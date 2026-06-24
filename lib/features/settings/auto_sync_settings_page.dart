import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auto_sync_service.dart';

class AutoSyncSettingsPage extends ConsumerStatefulWidget {
  const AutoSyncSettingsPage({super.key});

  @override
  ConsumerState<AutoSyncSettingsPage> createState() => _AutoSyncSettingsPageState();
}

class _AutoSyncSettingsPageState extends ConsumerState<AutoSyncSettingsPage> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _syncTimeController = TextEditingController(text: '09:00');
  final _gitRepoController = TextEditingController();

  bool _showPassword = false;
  bool _enableSync = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(autoSyncProvider.notifier).checkStatus();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _syncTimeController.dispose();
    _gitRepoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(autoSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自动同步设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(autoSyncProvider.notifier).checkStatus(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 状态卡片
          _buildStatusCard(syncState),
          const SizedBox(height: 16),

          // 安装/配置区域
          if (!syncState.isInstalled) ...[
            _buildInstallSection(),
          ] else if (!syncState.isConfigured) ...[
            _buildSetupSection(syncState),
          ] else ...[
            _buildManagementSection(syncState),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(AutoSyncState state) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (state.status) {
      case 'running':
        statusColor = Colors.green;
        statusText = '定时同步运行中';
        statusIcon = Icons.play_circle;
        break;
      case 'success':
        statusColor = Colors.blue;
        statusText = '同步成功';
        statusIcon = Icons.check_circle;
        break;
      case 'syncing':
        statusColor = Colors.orange;
        statusText = '正在同步...';
        statusIcon = Icons.sync;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusText = '同步失败';
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusText = state.isConfigured ? '待运行' : '未配置';
        statusIcon = Icons.info;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      if (state.lastSyncTime != null)
                        Text(
                          '上次同步: ${_formatDateTime(state.lastSyncTime!)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                if (state.isRunning)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          '守护进程',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (state.syncTime != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '每日自动同步时间: ${state.syncTime}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.error!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstallSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '安装自动同步系统',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '安装后将自动设置好浏览器自动化环境，支持每天自动登录抖音创作者后台并导出数据。',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final success = await ref.read(autoSyncProvider.notifier).install();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? '安装成功！' : '安装失败'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('安装自动同步系统'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupSection(AutoSyncState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '配置同步账号',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 手机号
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '抖音创作者账号手机号',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            // 密码
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: '账号密码',
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              obscureText: !_showPassword,
            ),
            const SizedBox(height: 12),

            // 同步时间
            TextField(
              controller: _syncTimeController,
              decoration: const InputDecoration(
                labelText: '每日自动同步时间',
                prefixIcon: Icon(Icons.access_time),
                hintText: '09:00',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // 多设备同步开关
            SwitchListTile(
              title: const Text('启用多设备同步'),
              subtitle: const Text('通过Git仓库同步数据到其他设备'),
              value: _enableSync,
              onChanged: (v) => setState(() => _enableSync = v),
              contentPadding: EdgeInsets.zero,
            ),

            if (_enableSync) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _gitRepoController,
                decoration: const InputDecoration(
                  labelText: 'Git仓库地址',
                  prefixIcon: Icon(Icons.cloud),
                  hintText: 'https://github.com/username/douyin-data.git',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '密码将加密存储在本地，不会上传到任何服务器。',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请填写完整的账号信息')),
                    );
                    return;
                  }

                  final success = await ref.read(autoSyncProvider.notifier).setup(
                    phone: _phoneController.text,
                    password: _passwordController.text,
                    syncTime: _syncTimeController.text,
                    gitRepo: _enableSync ? _gitRepoController.text : null,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? '配置成功！' : '配置失败'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('保存配置'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementSection(AutoSyncState state) {
    return Column(
      children: [
        // 操作按钮
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '同步控制',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: state.status == 'syncing'
                            ? null
                            : () async {
                                final success = await ref.read(autoSyncProvider.notifier).triggerSync();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success ? '同步完成！' : '同步失败'),
                                      backgroundColor: success ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.sync),
                        label: const Text('手动同步'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: state.isRunning
                          ? OutlinedButton.icon(
                              onPressed: () => ref.read(autoSyncProvider.notifier).stopDaemon(),
                              icon: const Icon(Icons.stop),
                              label: const Text('停止守护'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: () async {
                                final success = await ref.read(autoSyncProvider.notifier).startDaemon();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success ? '守护进程已启动' : '启动失败'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('启动守护'),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 使用说明
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.help_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '使用说明',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildHelpItem('1', '每天 ${state.syncTime ?? '09:00'} 自动执行数据同步'),
                _buildHelpItem('2', '守护进程在后台运行，不影响正常使用'),
                _buildHelpItem('3', '同步完成后会推送通知提醒'),
                _buildHelpItem('4', '多设备可通过Git仓库同步数据'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';

    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
