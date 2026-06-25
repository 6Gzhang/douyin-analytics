import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 技术展示页面 - 在 APP 内展示 HTML 页面
class TechShowcasePage extends StatefulWidget {
  const TechShowcasePage({super.key});

  @override
  State<TechShowcasePage> createState() => _TechShowcasePageState();
}

class _TechShowcasePageState extends State<TechShowcasePage> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      final dir = await _prepareAssets();

      if (!mounted) return;

      final controller = WebViewController.fromPlatformCreationParams(
        PlatformWebViewControllerCreationParams(),
      );

      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = '页面加载失败: ${e.description}';
              });
            }
          },
        ),
      );

      await controller.loadFile('${dir.path}/pages/index.html');
      _controller = controller;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// 将 tech-showcase 资源从 bundle 复制到临时目录
  Future<Directory> _prepareAssets() async {
    final tempDir = await getTemporaryDirectory();
    final showcaseDir = Directory('${tempDir.path}/tech-showcase');

    if (!await showcaseDir.exists()) {
      await showcaseDir.create(recursive: true);
      await Directory('${showcaseDir.path}/pages').create();

      // 复制 HTML 页面
      for (final page in ['index.html', 'dashboard.html', 'features.html']) {
        final data = await rootBundle.loadString('tech-showcase/pages/$page');
        await File('${showcaseDir.path}/pages/$page').writeAsString(data);
      }

      // 复制 CSS
      final css = await rootBundle.loadString('tech-showcase/colors_and_type.css');
      await File('${showcaseDir.path}/colors_and_type.css').writeAsString(css);
    }

    return showcaseDir;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Stack(
        children: [
          if (_error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() { _error = null; _loading = true; });
                      _initWebView();
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          else if (_controller != null)
            WebViewWidget(controller: _controller!),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}