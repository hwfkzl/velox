import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/services/remote_config_service.dart';
import '../../../core/theme/velox_colors.dart';
import '../../../l10n/app_localizations.dart';

class CrispPage extends StatefulWidget {
  const CrispPage({super.key});

  @override
  State<CrispPage> createState() => _CrispPageState();
}

class _CrispPageState extends State<CrispPage>
    with SingleTickerProviderStateMixin {
  // Windows 上没有 webview_flutter 实现（webview_flutter 依赖 WebView2 且未支持 Windows
  // desktop embedding），进入 CrispPage 会 MissingPluginException 直接崩溃。
  // 桌面 Windows 走 url_launcher 打开系统默认浏览器,避免依赖 WebView2 Runtime。
  bool get _useExternalBrowser => Platform.isWindows;

  WebViewController? _controller;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _fadeAnimation = _fadeController;

    final crispId = RemoteConfigService.instance.crispId;
    final url = 'https://go.crisp.chat/chat/embed/?website_id=$crispId';

    if (_useExternalBrowser) {
      // Windows：外部浏览器打开客服链接，UI 只放一个占位提示。
      scheduleMicrotask(() async {
        try {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {
          // 静默：不弹错误框，用户看到"已在浏览器中打开"占位就行
        }
        if (mounted) setState(() => _isLoading = false);
      });
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            // 等 Crisp JS 渲染完再隐藏
            await Future.delayed(const Duration(seconds: 2));
            if (!mounted) return;
            await _fadeController.reverse();
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          l10n.liveChat,
          style: const TextStyle(color: VeloxColors.textPrimary, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0D1B2E),
        iconTheme: const IconThemeData(color: VeloxColors.textPrimary),
        elevation: 0,
      ),
      body: _useExternalBrowser
          ? _buildExternalBrowserPlaceholder(l10n)
          : Stack(
              children: [
                if (_controller != null)
                  WebViewWidget(controller: _controller!),
                if (_isLoading)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      color: Colors.white,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: VeloxColors.primaryWithOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(
                                  color: VeloxColors.primary,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              l10n.connectingSupport,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A2B4A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.supportLoading,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8899AA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  /// Windows 分支占位：告知用户已在外部浏览器打开客服。
  Widget _buildExternalBrowserPlaceholder(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: VeloxColors.primaryWithOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.open_in_new_rounded,
                size: 32,
                color: VeloxColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.connectingSupport,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A2B4A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '已在系统浏览器中打开客服窗口',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF8899AA)),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () async {
                final crispId = RemoteConfigService.instance.crispId;
                final url =
                    'https://go.crisp.chat/chat/embed/?website_id=$crispId';
                try {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {}
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重新打开客服'),
            ),
          ],
        ),
      ),
    );
  }
}
