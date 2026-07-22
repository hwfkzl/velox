import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../core/services/app_updater.dart';
import '../../core/theme/velox/velox_tokens.dart';
import '../../data/models/remote_config_model.dart';
import '../../l10n/app_localizations.dart';
import 'velox/velox_snack.dart';

/// 应用内下载对话框(Android / Windows / macOS 共用)。
///
/// - Android:下载 APK → open 自动唤起安装器 → 用户确认安装
/// - Windows:下载 exe → open 运行
/// - macOS(方案 B 辅助更新):下载 dmg → 剥 quarantine → open 挂载并弹 Finder
///   下载完成后保持 dialog,提示用户把 Velox.app 拖到 Applications
class InAppUpdateDialog extends StatefulWidget {
  final UpdateCheckResult result;
  const InAppUpdateDialog({super.key, required this.result});

  @override
  State<InAppUpdateDialog> createState() => _InAppUpdateDialogState();
}

class _InAppUpdateDialogState extends State<InAppUpdateDialog> {
  double _progress = 0;
  bool _downloading = false;
  bool _verifying = false; // SHA256 校验中
  bool _macInstallPending = false; // macOS 下载完,等用户拖到 Applications
  bool _stalled = false; // 下载 30s 无进度 —— 必须允许关闭 dialog 即使 must:true
  String? _errorMsg;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _verifying = false;
      _errorMsg = null;
      _progress = 0;
      _macInstallPending = false;
      _stalled = false;
    });
    _cancelToken = CancelToken();

    final result = await AppUpdater.instance.downloadAndInstall(
      widget.result.downloadUrl,
      expectedSha256: widget.result.sha256,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
      onVerifying: () {
        if (mounted) setState(() => _verifying = true);
      },
      cancelToken: _cancelToken,
    );

    if (!mounted) return;

    switch (result) {
      case AppUpdateResult.success:
        // macOS:dmg 已挂载 + Finder 已弹出,改为"等待用户拖到 Applications"状态
        if (Platform.isMacOS) {
          setState(() {
            _downloading = false;
            _verifying = false;
            _macInstallPending = true;
          });
        } else {
          Navigator.of(context).pop();
        }
        break;
      case AppUpdateResult.permissionDenied:
        setState(() {
          _downloading = false;
          _verifying = false;
          _errorMsg = '需要「安装未知来源应用」权限';
        });
        break;
      case AppUpdateResult.cancelled:
        setState(() {
          _downloading = false;
          _verifying = false;
        });
        break;
      case AppUpdateResult.checksumFailed:
        setState(() {
          _downloading = false;
          _verifying = false;
          _errorMsg = '文件校验失败，安装包可能已损坏或被篡改，请重试或联系客服';
        });
        break;
      case AppUpdateResult.insecureUrl:
        setState(() {
          _downloading = false;
          _verifying = false;
          _errorMsg = '更新地址不安全（非 HTTPS），已取消';
        });
        break;
      case AppUpdateResult.xattrFailed:
        setState(() {
          _downloading = false;
          _verifying = false;
          _errorMsg = '无法移除系统隔离标记，请重试';
        });
        break;
      case AppUpdateResult.downloadFailed:
      case AppUpdateResult.openFailed:
        setState(() {
          _downloading = false;
          _verifying = false;
          _errorMsg = '下载失败，请检查网络后重试';
        });
        break;
      case AppUpdateResult.stalled:
        // 30s 无进度 —— 视为卡死。切到 stalled UI(按钮变 [关闭][重试],
        // 关闭按钮即使在 must:true 强制更新场景也生效,主动 Navigator.pop 不受 barrier 拦截)
        // 复用全 app 统一玻璃 snackbar 展示错误文案(带当前版本号,方便客服排障)
        setState(() {
          _downloading = false;
          _verifying = false;
          _stalled = true;
          _errorMsg = null; // stalled 独立 UI,不走 _errorMsg 红字通道
        });
        showVeloxSnack(
          context,
          '当前版本 v${widget.result.currentVersion}，更新失败，请联系客服',
          isError: true,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;
    final must = widget.result.must;
    final canDismiss = !must && !_downloading;

    // 跟 showVeloxInfoDialog 同款玻璃容器(全 app 对话框统一语言)
    return PopScope(
      canPop: canDismiss,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: v.blurHeavy,
                sigmaY: v.blurHeavy,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                decoration: BoxDecoration(
                  color: v.surfaceMid,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: v.divider, width: 1),
                  boxShadow: v.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _macInstallPending ? '请完成安装' : l10n.updateTitle,
                      style: TextStyle(
                        color: v.text1,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'v${widget.result.currentVersion}  →  v${widget.result.latestVersion}',
                      style: TextStyle(
                        color: v.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.result.message.isNotEmpty &&
                        !_macInstallPending &&
                        !_stalled) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.result.message,
                        style: TextStyle(
                          color: v.text2,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (_downloading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _verifying
                            ? null
                            : (_progress > 0 ? _progress : null),
                        backgroundColor: v.divider,
                        valueColor: AlwaysStoppedAnimation(v.accent),
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _verifying
                            ? '校验中...'
                            : (_progress > 0
                                ? '${(_progress * 100).toStringAsFixed(0)}%'
                                : '准备下载...'),
                        style: TextStyle(color: v.text3, fontSize: 12),
                      ),
                    ],
                    if (_macInstallPending) ...[
                      const SizedBox(height: 12),
                      Text(
                        '1. 已在 Finder 中打开新版本\n'
                        '2. 请把「${Brand.name}」拖到「应用程序」文件夹覆盖旧版\n'
                        '3. 完成后退出本窗口并重新启动 ${Brand.name}',
                        style: TextStyle(
                          color: v.text2,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMsg!,
                        style: TextStyle(color: v.danger, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildActions(l10n, must, v),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 按钮区:用 showVeloxInfoDialog 同款的"accent 玻璃按钮"语言
  Widget _buildActions(AppLocalizations l10n, bool must, VeloxTokens v) {
    // stalled 优先级最高 —— 必须放在 must 分支之前,保证 must:true 强制更新
    // 卡死场景也能命中并允许关闭对话框。主动 Navigator.pop 不受 barrierDismissible
    // / PopScope canPop 拦截,即使强制更新亦可关。
    if (_stalled) {
      return Row(
        children: [
          Expanded(
            child: _glassButton(
              v: v,
              label: l10n.close,
              primary: false,
              onTap: () {
                _cancelToken?.cancel();
                Navigator.of(context).pop();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _glassButton(
              v: v,
              label: l10n.retry,
              primary: true,
              onTap: _startDownload,
            ),
          ),
        ],
      );
    }

    if (_downloading) {
      return _glassButton(
        v: v,
        label: l10n.cancel,
        primary: false,
        onTap: () {
          _cancelToken?.cancel();
          setState(() => _downloading = false);
        },
      );
    }

    if (_macInstallPending) {
      return _glassButton(
        v: v,
        label: '完成',
        primary: true,
        onTap: () => Navigator.of(context).pop(),
      );
    }

    if (must) {
      return _glassButton(
        v: v,
        label: l10n.updateNow,
        primary: true,
        onTap: _startDownload,
      );
    }

    // 非强制更新:左 ghost(暂不) + 右 accent(立即),两按钮横向均分
    return Row(
      children: [
        Expanded(
          child: _glassButton(
            v: v,
            label: l10n.skipUpdate,
            primary: false,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _glassButton(
            v: v,
            label: l10n.updateNow,
            primary: true,
            onTap: _startDownload,
          ),
        ),
      ],
    );
  }

  /// 玻璃按钮:跟 showVeloxInfoDialog 的"好的"按钮同语言。
  /// primary=true:accent 蓝玻璃 / primary=false:中性灰玻璃。
  Widget _glassButton({
    required VeloxTokens v,
    required String label,
    required bool primary,
    required VoidCallback onTap,
  }) {
    final bg = primary
        ? v.accent.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.06);
    final borderColor = primary
        ? v.accent.withValues(alpha: 0.40)
        : v.divider;
    final textColor = primary ? v.accent : v.text2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
