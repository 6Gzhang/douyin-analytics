import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../services/ai_service.dart';

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key});

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  bool _typing = false;

  bool get _hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _addIntro();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _apiKey = prefs.getString('dashscope_api_key'));
  }

  void _addIntro() {
    if (_hasApiKey) {
      _messages.add(_ChatMessage(
        isUser: false,
        text: '你好！我是你的 AI 分析助手。\n'
            '可以帮你分析视频数据、诊断频道表现、推荐爆款标题。\n'
            '点击下方快捷提问或直接输入问题～',
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (!_hasApiKey) return;

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
      _loading = true;
      _typing = true;
    });
    _controller.clear();

    final systemPrompt = '你是抖音数据分析助手 Douyin Analytics AI，简称 DA-AI。'
        '你精通抖音内容运营策略、数据分析、标题创作、受众分析。'
        '回答要专业、简洁、可操作，每次回答控制在200字以内。';

    final reply = await AiService.instance.chat(systemPrompt, text);

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(isUser: false, text: reply));
      _loading = false;
      _typing = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 分析助手'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (!_hasApiKey) _buildConfigureGuide(),
          Expanded(child: _buildChatList()),
          if (_hasApiKey) _buildPresetChips(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildConfigureGuide() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentBlue.withValues(alpha: 0.08),
            AppTheme.accentPurple.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, size: 40, color: AppTheme.accentBlue),
          const SizedBox(height: 12),
          const Text('AI 助手需要配置 API Key',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            '前往设置 → AI 助手配置 → 填入阿里云百炼 API Key\n（免费注册送 100 万 Tokens）',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.go('/settings');
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('前往设置'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_typing ? 1 : 0),
      itemBuilder: (context, index) {
        if (_typing && index == _messages.length) {
          return _buildTypingIndicator();
        }
        final msg = _messages[index];
        return _buildBubble(msg);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dot(),
              const SizedBox(width: 4),
              _dot(delay: 200),
              const SizedBox(width: 4),
              _dot(delay: 400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot({int delay = 0}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, value, __) {
        return Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: AppTheme.accentBlue),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.accentBlue
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser ? Colors.white : null,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildPresetChips() {
    final chips = [
      '分析表现',
      '优化方向',
      '爆款标题',
      '内容问题',
      '发布时间',
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(chips[index], style: const TextStyle(fontSize: 12)),
            onPressed: _loading ? null : () => _sendMessage(chips[index]),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    if (!_hasApiKey) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: '输入问题...',
                hintStyle: TextStyle(fontSize: 14),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: _loading ? null : (text) => _sendMessage(text),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _loading
                ? null
                : () => _sendMessage(_controller.text),
            icon: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool isUser;
  final String text;
  _ChatMessage({required this.isUser, required this.text});
}
