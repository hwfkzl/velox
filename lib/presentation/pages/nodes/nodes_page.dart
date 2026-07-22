import 'dart:async';
import 'dart:io';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/auto_test_service.dart';
import '../../../core/services/latency_display.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../di/injection.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../core/utils/localized_error_mapper.dart';
import '../../../data/models/server_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/node/node_bloc.dart';
import '../../blocs/vpn/vpn_bloc.dart';
import '../../widgets/velox/velox_back_button.dart';
import '../../widgets/velox/velox_scaffold.dart';

class NodesPage extends StatefulWidget {
  const NodesPage({super.key});

  @override
  State<NodesPage> createState() => _NodesPageState();
}

class _NodesPageState extends State<NodesPage> {
  bool _autoConnect = false;
  String _proxyMode = 'rule'; // 仅 'rule' | 'global'，不含 'tun'
  bool _tunEnabled = false;   // TUN 独立开关

  /// TUN 切换防抖：快速连续点击只取最后一次实际派发，避免 mihomo 反复重启。
  /// bloc 事件串行处理，无防抖时 N 次点击会触发 N 次完整重连（root↔user 权限切换），
  /// 队列消化耗时 N×3s，UI 表现为卡顿。
  Timer? _tunToggleDebouncer;
  static const _tunToggleDebounceMs = 350;

  /// 订阅 VpnBloc 状态：tray menu 等外部入口改 prefs 后会 dispatch event 触发 bloc
  /// 状态变化，借此把最新 TUN/proxyMode 同步回本地 widget state，避免 UI 撒谎。
  StreamSubscription<VpnState>? _vpnSub;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 只在 status / server 真正变化时才 reload — 忽略每秒一次的 stats event
    // (uploadSpeed/downloadSpeed/totalUpload 等无关字段更新)。否则每秒 setState
    // 一次,UI 持续 rebuild 导致 toggle 动画抖动。
    _vpnSub ??= context.read<VpnBloc>().stream
        .distinct((prev, next) =>
            prev.status == next.status && prev.server?.id == next.server?.id)
        .listen((_) {
      if (mounted) _loadSettings();
    });
  }

  @override
  void dispose() {
    _tunToggleDebouncer?.cancel();
    _vpnSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rawMode = prefs.getString(StorageKeys.proxyMode) ?? 'rule';
    final autoConnect = prefs.getBool(StorageKeys.autoConnect) ?? false;

    // TUN 状态：从专用 key 读取；兼容旧版（proxyMode == 'tun'）
    bool tunEnabled = prefs.getBool(StorageKeys.tunEnabled) ?? false;
    String baseMode;
    if (rawMode == 'tun') {
      // 旧数据迁移：proxyMode 存了 'tun'，迁移到新结构
      tunEnabled = true;
      baseMode = prefs.getString(StorageKeys.lastProxyMode) ?? 'rule';
      await prefs.setString(StorageKeys.proxyMode, 'tun');
      await prefs.setBool(StorageKeys.tunEnabled, true);
    } else if (rawMode == 'direct') {
      baseMode = 'rule';
      await prefs.setString(StorageKeys.proxyMode, tunEnabled ? 'tun' : 'rule');
    } else {
      baseMode = rawMode;
    }

    // Windows 通过 bundled wintun.dll + ShellExecuteEx runas 提权 mihomo 子进程
    // 支持 TUN 模式（Plan C），无需再强制清理 TUN 状态。

    // 只在值真的变化时才 setState,避免 listener 触发后无谓 rebuild 打断 toggle 动画。
    // 切 TUN 时 _onTunModePatched 会连发 emit(connecting) + emit(connected),
    // 两次 listener 都会跑到这里,但 prefs 写入是用户切之前 _toggleTun 就做了的,
    // 所以这里读到的值 == 当前本地 state → 该判断让 setState 一次都不发生。
    if (mounted &&
        (_proxyMode != baseMode ||
            _tunEnabled != tunEnabled ||
            _autoConnect != autoConnect)) {
      setState(() {
        _proxyMode = baseMode;
        _tunEnabled = tunEnabled;
        _autoConnect = autoConnect;
      });
    }
  }

  /// TUN 开关切换（带防抖）
  /// UI 立即更新 → 真正的 prefs 写入 + bloc 派发延后 350ms。
  /// 期间任何新点击会重置定时器并刷新 UI，最终只派发一次"用户最终态"。
  void _toggleTun(bool enabled) {
    if (mounted) setState(() => _tunEnabled = enabled);

    _tunToggleDebouncer?.cancel();
    _tunToggleDebouncer = Timer(
      const Duration(milliseconds: _tunToggleDebounceMs),
      _flushTunToggle,
    );
  }

  /// 实际把 UI 当前状态 `_tunEnabled` 持久化到 prefs 并通知 bloc。
  /// 已连接 → 完整重连；未连接/连接中 → 只更新 prefs。
  Future<void> _flushTunToggle() async {
    if (!mounted) return;
    final vpnBloc = context.read<VpnBloc>();
    final finalEnabled = _tunEnabled;

    final prefs = await SharedPreferences.getInstance();
    if (finalEnabled) {
      final modeToSave = (_proxyMode == 'tun') ? 'rule' : _proxyMode;
      await prefs.setString(StorageKeys.lastProxyMode, modeToSave);
      await prefs.setString(StorageKeys.proxyMode, 'tun');
      await prefs.setBool(StorageKeys.tunEnabled, true);
    } else {
      final raw = prefs.getString(StorageKeys.lastProxyMode) ?? _proxyMode;
      final restored = (raw == 'tun' || raw.isEmpty) ? 'rule' : raw;
      await prefs.setString(StorageKeys.proxyMode, restored);
      await prefs.setBool(StorageKeys.tunEnabled, false);
    }

    final vpnState = vpnBloc.state;
    if (vpnState.status == VpnStatus.connected && vpnState.server != null) {
      vpnBloc.add(VpnTunModePatched(enabled: finalEnabled));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final v = context.velox;
    return Scaffold(
      backgroundColor: v.bg0,
      body: VeloxScaffold(
        child: SafeArea(
          child: Column(
        children: [
          _NodesTopBar(
            title: l10n.selectNode,
            testLabel: l10n.testAllNodes,
            updateLabel: l10n.updateNodes,
          ),
          // 控制 pill 组：代理模式 / TUN / 自动选择，紧凑横向胶囊
          //   节省垂直空间（150px → ~50px），跟首页节点 pill 视觉一致
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ControlPill(
                  icon: Icons.language,
                  label: l10n.proxyMode,
                  valueText: _proxyMode == 'global'
                      ? l10n.proxyModeGlobal
                      : l10n.proxyModeRule,
                  onTap: () => _showProxyModeDialog(),
                ),
                if (Platform.isMacOS || Platform.isWindows)
                  // 只在 disconnecting 期间禁用 TUN 切换（断开是几秒的过程，避免在
                  // 队列里堆积切换事件）。connecting 不算 busy —— 切 TUN 走 patchTunMode
                  // 热重载，毫秒级过渡 connecting → connected，期间 disable 会导致
                  // toggle 灰一下闪烁；并且 _toggleTun 已用 350ms debouncer 抗连点。
                  BlocBuilder<VpnBloc, VpnState>(
                    buildWhen: (prev, curr) =>
                        (prev.status == VpnStatus.disconnecting) !=
                        (curr.status == VpnStatus.disconnecting),
                    builder: (context, vpnState) {
                      final busy =
                          vpnState.status == VpnStatus.disconnecting;
                      return _ControlPill(
                        icon: Icons.lan_outlined,
                        label: l10n.proxyModeTun,
                        toggleValue: _tunEnabled,
                        onToggle: (v) => _toggleTun(v),
                        enabled: !busy,
                      );
                    },
                  ),
                // 「自动选择」UI 已隐藏（功能不需要）。底层 SettingsService.autoConnect
                // 永远保持 false，不影响其他模块行为。
              ],
            ),
          ),
          // 节点列表
          Expanded(
            child: BlocBuilder<NodeBloc, NodeState>(
              builder: (context, state) {
                if (state is NodeLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is NodeError) {
                  final localizedMsg = LocalizedErrorMapper.getLocalizedError(l10n, state.message);
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(localizedMsg,
                            style: TextStyle(color: v.text2)),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            context.read<NodeBloc>().add(NodeLoadRequested());
                          },
                          child: Text(
                            l10n.retry,
                            style: TextStyle(color: v.accent),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (state is NodeLoaded) {
                  if (state.servers.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.noNodesSubscribe,
                        style: TextStyle(color: v.text3),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<NodeBloc>().add(NodeRefreshRequested());
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: state.servers.length,
                      itemBuilder: (context, index) {
                        final server = state.servers[index];
                        // 自动选择 ON 时不高亮任何节点，避免用户误以为该节点是当前连接节点
                        final isSelected = !_autoConnect &&
                            state.selectedServer?.id == server.id;

                        return _NodeListItem(
                          server: server,
                          isSelected: isSelected,
                          onTap: () async {
                            // 用户手动点节点时：
                            //   1. 关闭自动选择开关（避免后台立刻又把节点切走）
                            //   2. 清除 AutoTestService 内部的 override，避免污染下次自动选择
                            //   3. 标记为已选中
                            //   4. 已连接状态 + 切到不同节点 → fast-switch
                            //      （行业标准：Clash Verge / mihomo Party 都是即时切换，
                            //       走 PUT /proxies/PROXY 不重启 mihomo 进程，零停顿）
                            //   5. 未连接 → 不发起连接，等用户回首页点"连接"按钮
                            if (_autoConnect) {
                              await SettingsService.instance.setAutoConnect(false);
                              setState(() => _autoConnect = false);
                            }
                            getIt<AutoTestService>().forceSet(null);

                            if (!context.mounted) return;
                            context.read<NodeBloc>().add(
                                  NodeSelectRequested(server: server),
                                );

                            final vpnState = context.read<VpnBloc>().state;
                            // 仅在"已连接 + 选了不同节点"时即时切换；
                            // 未连接 / 同一节点 / 连接中 都不触发
                            if (vpnState.isConnected &&
                                vpnState.server?.id != server.id) {
                              context.read<VpnBloc>().add(
                                    VpnConnectRequested(
                                      server: server,
                                      allServers: state.servers,
                                    ),
                                  );
                            }
                          },
                          onFavoriteToggle: () {
                            if (server.id != null) {
                              context.read<NodeBloc>().add(
                                    NodeToggleFavoriteRequested(serverId: server.id!),
                                  );
                            }
                          },
                        );
                      },
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  Future<void> _showProxyModeDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    // dialog 仅显示 rule/global；TUN 时显示当前 lastProxyMode 或 _proxyMode
    String selectedMode = _tunEnabled
        ? (prefs.getString(StorageKeys.lastProxyMode) ?? _proxyMode)
        : (prefs.getString(StorageKeys.proxyMode) ?? 'rule');
    if (selectedMode == 'tun' || selectedMode == 'direct') selectedMode = 'rule';
    final vpnBloc = context.read<VpnBloc>();

    void onModeSelected(String value) {
      // 立即刷新 UI；持久化 + 即时生效（TUN 开着热重载、非 TUN 重连）统一交给
      // VpnBloc._onProxyModeChanged，与托盘菜单走同一条路径，避免逻辑分叉。
      if (mounted) setState(() => _proxyMode = value);
      vpnBloc.add(VpnProxyModeChanged(mode: value));
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      // 深色弹窗：与主体深色主题一致
      backgroundColor: const Color(0xFF0E2747).withValues(alpha: 0.97),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      builder: (context) {
        final v = context.velox;
        return StatefulBuilder(
          builder: (context, setState) => SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部拖动 handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.proxyMode,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: v.text1,
                  ),
                ),
              const SizedBox(height: 12),
              _buildModeOption(
                title: l10n.proxyModeRule,
                subtitle: l10n.proxyModeRuleSubtitle,
                value: 'rule',
                groupValue: selectedMode,
                recommended: true,
                onChanged: (value) {
                  setState(() => selectedMode = value!);
                  onModeSelected(value!);
                },
              ),
              _buildModeOption(
                title: l10n.proxyModeGlobal,
                subtitle: l10n.proxyModeGlobalSubtitle,
                value: 'global',
                groupValue: selectedMode,
                onChanged: (value) {
                  setState(() => selectedMode = value!);
                  onModeSelected(value!);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
      },
    );
  }

  Widget _buildModeOption({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    bool recommended = false,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: v.accent.withValues(alpha: 0.08),
          highlightColor: v.accent.withValues(alpha: 0.04),
          onTap: () {
            onChanged(value);
            Navigator.pop(context);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              // 深色弹窗里的选项卡片：未选 = 微弱玻璃；选中 = accent 染色
              color: isSelected
                  ? v.accent.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? v.accent.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.10),
                width: isSelected ? 1.3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: v.accent.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: v.text1,
                          ),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: v.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: v.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              l10n.recommended,
                              style: TextStyle(
                                fontSize: 9,
                                color: v.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: v.text3),
                    ),
                  ],
                ),
              ),
              Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? v.accent : Colors.transparent,
                  border: isSelected
                      ? null
                      : Border.all(
                          color: v.divider,
                          width: 1.5,
                        ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}


/// Nodes-page top bar: centered title, back on the left, speed-test +
/// refresh on the right — both with press-blue feedback like the home bar.
class _NodesTopBar extends StatelessWidget {
  const _NodesTopBar({
    required this.title,
    required this.testLabel,
    required this.updateLabel,
  });

  final String title;
  final String testLabel;
  final String updateLabel;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: v.text1,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const VeloxBackButton(),
              Row(
                children: [
                  BlocBuilder<NodeBloc, NodeState>(
                    builder: (context, state) {
                      final isPinging =
                          state is NodeLoaded && state.isPinging;
                      return _IconAction(
                        icon: isPinging ? null : Icons.speed_rounded,
                        busy: isPinging,
                        label: testLabel,
                        onTap: isPinging
                            ? null
                            : () => context
                                .read<NodeBloc>()
                                .add(NodePingAllRequested()),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  _IconAction(
                    icon: Icons.refresh_rounded,
                    label: updateLabel,
                    onTap: () => context
                        .read<NodeBloc>()
                        .add(NodeRefreshRequested()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatefulWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final disabled = widget.onTap == null;
    final color = (_pressed && !disabled) ? v.accent : v.text2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:
          disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: v.accent,
                    ),
                  )
                : Icon(widget.icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: TextStyle(fontSize: 10, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeListItem extends StatelessWidget {
  final ServerModel server;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const _NodeListItem({
    required this.server,
    required this.isSelected,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  /// Color palette for the latency pill:
  ///   < 0 (-2 后端离线 / -1 网络超时) → 红色 danger（统一"超时"红框）
  ///   < 100ms → success green
  ///   < 300ms → warning amber
  ///   ≥ 300ms / null → danger
  ///
  /// 用 [latencyForDisplay] 翻译后的延迟决定颜色——开启 OSS 包装时全员绿色，
  /// 颜色和显示数字保持一致（否则会出现"50ms 红色"的撞色穿帮）。
  Color _latencyColor(VeloxTokens v) {
    final l = latencyForDisplay(server.latency, server.id ?? 0);
    if (l == null || l < 0) return v.danger;
    if (l < 100) return v.success;
    if (l < 300) return v.warning;
    return v.danger;
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final latencyColor = _latencyColor(v);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      // Selection cue is pure elevation: no hard border change. The card
      // gets a subtle accent-tinted bg, a stronger drop shadow, and a
      // micro scale-up — reads as "this one floats above the rest".
      child: AnimatedScale(
        scale: isSelected ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: v.accent.withValues(alpha: 0.08),
            highlightColor: v.accent.withValues(alpha: 0.04),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                // 深色玻璃节点行：
                //   - 普通态：极弱白色玻璃（克制，不抢戏）
                //   - 选中态：accent 染色 + 边框 + 单层光晕（清晰但不过曝）
                color: isSelected
                    ? v.accent.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? v.accent.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 1.2 : 1,
                ),
                // 普通态不要光晕（多行堆叠会让整个列表"蓝光泛滥"）
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: v.accent.withValues(alpha: 0.32),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
            child: Row(
              children: [
                _buildNodeIcon(v, server.tags),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: v.text1, // always readable slate-900
                        ),
                      ),
                      // 用户要求:节点列表不显示倍率 chip(1.5x 等)
                    ],
                  ),
                ),
                if (server.latency != null) ...[
                  const SizedBox(width: 8),
                  Builder(builder: (context) {
                    final display =
                        latencyForDisplay(server.latency, server.id ?? 0);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: latencyColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: latencyColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        // 负数（-2 后端离线 / -1 网络超时）统一显示"超时"
                        (display == null || display < 0)
                            ? (AppLocalizations.of(context)?.latencyTimeout ??
                                '超时')
                            : '${display}ms',
                        style: TextStyle(
                          fontSize: 12,
                          color: latencyColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  String? _getCountryCode(List<String>? tags) {
    if (tags == null || tags.isEmpty) return null;
    for (final tag in tags) {
      if (tag.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(tag)) {
        return tag.toUpperCase();
      }
    }
    return null;
  }

  Widget _buildNodeIcon(VeloxTokens v, List<String>? tags) {
    final code = _getCountryCode(tags);
    if (code != null) {
      return ClipOval(
        child: CountryFlag.fromCountryCode(code, width: 30, height: 30),
      );
    }
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: v.accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.dns_rounded, color: v.accent, size: 16),
    );
  }
}

/// 紧凑控制 pill —— 跟首页节点 pill 同语言（圆角玻璃 + 微染色边框）。
/// 两种模式：
///   - 导航模式（valueText != null）：显示当前值 + chevron，点击触发 onTap
///   - 开关模式（toggleValue != null）：右侧显示 LED 状态点，点击触发 onToggle
class _ControlPill extends StatefulWidget {
  const _ControlPill({
    required this.icon,
    required this.label,
    this.valueText,
    this.toggleValue,
    this.onTap,
    this.onToggle,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? valueText;
  final bool? toggleValue;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;
  /// false 时整个 pill 灰显且不响应点击。
  final bool enabled;

  @override
  State<_ControlPill> createState() => _ControlPillState();
}

class _ControlPillState extends State<_ControlPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final hasToggle = widget.toggleValue != null;
    final active = hasToggle && widget.toggleValue == true;
    final disabled = !widget.enabled;

    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? v.accent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? v.accent.withValues(alpha: 0.55)
              : (_pressed
                  ? v.accent.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.12)),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.icon,
            size: 16,
            color: active ? v.accent : v.text2,
          ),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? v.accent : v.text1,
            ),
          ),
          // 导航模式：显示当前值 + chevron
          if (widget.valueText != null) ...[
            const SizedBox(width: 6),
            Text(
              '· ${widget.valueText}',
              style: TextStyle(fontSize: 12, color: v.text3),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 16, color: v.text3),
          ],
          // 开关模式：LED 状态点（亮蓝表示开，灰表示关）
          if (hasToggle) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? v.accent : v.text4,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: v.accent.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ],
      ),
    );

    if (disabled) {
      // 灰显 + 吸收点击事件（IgnorePointer + 半透明）
      return IgnorePointer(
        child: Opacity(opacity: 0.45, child: pill),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        if (hasToggle) {
          widget.onToggle?.call(!widget.toggleValue!);
        } else {
          widget.onTap?.call();
        }
      },
      child: pill,
    );
  }
}
