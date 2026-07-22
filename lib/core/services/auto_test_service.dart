import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:singbox_flutter/singbox_flutter.dart';

import '../../data/models/server_model.dart';

/// 单个节点的测速状态
class _ProxyTestState {
  bool alive = false;
  final Queue<int> history = Queue<int>();

  /// 死节点返回 0xFFFF，确保排最后
  int get lastDelay {
    if (!alive || history.isEmpty) return 0xFFFF;
    return history.last;
  }
}

/// 单个节点测速完成后的推送结果
class DelayResult {
  final int serverId;
  final int latency; // >0 正常延迟(ms)，-1 超时/失败

  const DelayResult({required this.serverId, required this.latency});
}

/// 自动测速服务（双模式：VPN 运行中用 Clash API，否则用 TCP Ping）
class AutoTestService {
  // ── 调度层 ──
  Timer? _timer;
  bool _isTesting = false;

  // ── VPN 状态（由 VpnBloc 注入）──
  bool _isVpnConnected = false;

  // ── 选择层 ──
  final _states = <int, _ProxyTestState>{};
  ServerModel? _fastNode;
  ServerModel? _selectedOverride;
  DateTime? _fastCacheTime;

  // ── 推送 Stream ──
  final _controller = StreamController<DelayResult>.broadcast();
  Stream<DelayResult> get delayStream => _controller.stream;

  // ── 一轮测速完成通知（用于触发自动切换最优节点） ──
  final _runCompletedController = StreamController<void>.broadcast();
  Stream<void> get runOnceCompleted => _runCompletedController.stream;

  // Mihomo Clash API 端口（19090，避开 Clash Verge 等客户端默认的 9090）
  static const _clashApiPort = 19090;

  // ─────────────────────────────────────────────
  // VPN 状态注入（由 VpnBloc 调用）
  // ─────────────────────────────────────────────

  void setVpnState({required bool connected, int? connectedServerId}) {
    _isVpnConnected = connected;
    // 注意：不再记录 _connectedServerId。
    // 旧实现按"是否是当前节点"决定测速方式（Clash API vs TCP ping），
    // 两种方式度量不同步会引发 URLTest flipping bug。
    // 新实现：VPN 运行时全部走 Clash API /proxies/{name}/delay，度量一致。
    debugPrint('[AutoTest] VPN state: connected=$connected, serverId=$connectedServerId');
  }

  // ─────────────────────────────────────────────
  // 调度层
  // ─────────────────────────────────────────────

  void startPeriodic({
    required Future<List<ServerModel>> Function() getServers,
    int intervalSeconds = 300,
  }) {
    _timer?.cancel();

    // getServers 内部会调 API,失败(401/network)时安静返回空列表继续调度。
    // 不 throw 就不会污染 dart root zone(修 Ultracode 报告的 "登录已过期" Unhandled Exception 刷屏)。
    Future<List<ServerModel>> safeGetServers() async {
      try {
        return await getServers();
      } catch (e) {
        debugPrint('[AutoTest] getServers failed: $e — 跳过本轮');
        return const [];
      }
    }

    // 启动时立即跑一次
    Future.microtask(() async {
      final servers = await safeGetServers();
      if (servers.isNotEmpty) await runOnce(servers);
    });

    // 周期任务:失败静默,永不抛出
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      final servers = await safeGetServers();
      if (servers.isNotEmpty) await runOnce(servers);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  // ─────────────────────────────────────────────
  // 测试层
  // ─────────────────────────────────────────────

  Future<void> runOnce(List<ServerModel> servers) async {
    if (_isTesting) return;
    // 隐私修复:VPN 未连时跳过 TCP ping。之前会 TCP 握手 46 个节点走 Mac
    // 真实 ISP,后端节点日志里能看到用户真实 IP。VPN 未连 → 用户不需要测速
    // 结果,离线 lastState 就够 UI 展示。
    if (!_isVpnConnected) {
      debugPrint('[AutoTest] ⏭ 跳过 runOnce:VPN 未连接,防真实 IP 泄漏给节点');
      return;
    }
    _isTesting = true;
    debugPrint('[AutoTest] ▶ runOnce 开始，共 ${servers.length} 个节点');

    try {
      final chunks = <List<ServerModel>>[];
      for (var i = 0; i < servers.length; i += 10) {
        chunks.add(servers.sublist(
          i,
          (i + 10 > servers.length) ? servers.length : i + 10,
        ));
      }

      for (final chunk in chunks) {
        await Future.wait(
          chunk.map((server) async {
            if (server.id == null) return;
            await _pingOne(server);
          }),
        );
      }
    } finally {
      _isTesting = false;
      debugPrint('[AutoTest] ✅ runOnce 完成');
      // 通知订阅者一轮测速已完成（例如 VpnBloc 用来决定是否自动切换最优节点）
      if (!_runCompletedController.isClosed) {
        _runCompletedController.add(null);
      }
    }
  }

  Future<void> _pingOne(ServerModel server) async {
    int latency;

    // ── 行业标准（Clash Verge URLTest）：测速必须全部用同一种方法，否则不公平 ──
    //
    // VPN 运行时：
    //   所有节点统一走 Clash API 测单个 proxy 的 RTT（GET /proxies/{name}/delay），
    //   这样每个节点测出的都是"通过该 proxy 的真实往返延迟"，对比公平。
    //
    // VPN 未运行时：
    //   回退到 TCP Ping（只是直连 server:port 的 TCP 握手，不经过代理）。
    //   此时自动选择不会触发自动切换，只是为 UI 显示延迟。
    //
    // ⚠️ 之前的实现：当前节点走 Clash API（RTT 包含代理 overhead ~150ms），
    //    其他节点走 TCP ping（只有握手 ~50ms），对比永远是"当前最慢" →
    //    后台自动切换会把流量切到别的节点 → 切完对方变"当前" → 又切回去 →
    //    无限 flipping bug。
    // L0 后端权威：服务端 5 分钟未上报心跳 → 直接判离线
    // 跳过 TCP 探测（避免 CDN 中转架构下的假阳性）和 Clash API（节省 ~5s 超时）
    if (server.backendOnline == 0) {
      latency = -2; // 区别于 -1 (网络超时)，UI 显示"离线"灰色
      debugPrint('[AutoTest] 🚫 节点 ${server.id} 后端 is_online=0，跳过探测');
    } else if (_isVpnConnected) {
      // L3 Clash API URL test：经过节点真实代理 GET generate_204
      // 用 config generator 同一个命名函数，保证 auto-test 的 proxy 名永远和
      // mihomo 配置里的对得上（{type}-{id}，如 trojan-56 / anytls-47 / vless-9）。
      // 之前硬编 'proxy-${id}' 跟实际配置不匹配 → mihomo 返 404 → 全部误判 DEAD。
      final proxyName =
          MihomoConfigGenerator.proxyNameForId(server.id!, server.type);
      latency = await _clashApiDelayForProxy(proxyName);
      debugPrint('[AutoTest] 📡 节点 ${server.id} (Clash API /proxies/$proxyName/delay) → '
          '${latency > 0 ? '${latency}ms' : 'DEAD'}');
    } else {
      // L1 TCP 握手：VPN 未连时的回退方案（注意 CDN 假阳性）
      latency = await _tcpPing(server);
      debugPrint('[AutoTest] 📡 节点 ${server.id} (TCP) → ${latency > 0 ? '${latency}ms' : 'DEAD'}');
    }

    final alive = latency > 0;
    final state = _states.putIfAbsent(server.id!, () => _ProxyTestState());
    state.alive = alive;
    state.history.addLast(alive ? latency : 0xFFFF);
    if (state.history.length > 10) state.history.removeFirst();

    if (!_controller.isClosed) {
      _controller.add(DelayResult(
        serverId: server.id!,
        // -2 后端离线 / -1 网络超时 / 正数 实际延迟
        latency: alive ? latency : (latency == -2 ? -2 : -1),
      ));
    }
  }

  /// Clash API 测速：测**特定 proxy** 的真实 RTT（经过该 proxy 访问 testUrl 的往返时间）。
  ///
  /// URL: GET /proxies/{proxyName}/delay?url={testUrl}&timeout={ms}
  /// 返回: {"delay": number} 或超时时 4xx/5xx
  Future<int> _clashApiDelayForProxy(
    String proxyName, {
    String testUrl = 'http://www.gstatic.com/generate_204',
    int timeoutMs = 5000,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = Duration(milliseconds: timeoutMs + 1000);

      final encodedUrl = Uri.encodeQueryComponent(testUrl);
      final uri = Uri.parse(
        'http://127.0.0.1:$_clashApiPort/proxies/$proxyName/delay'
        '?url=$encodedUrl&timeout=$timeoutMs',
      );

      final request = await client.getUrl(uri)
          .timeout(Duration(milliseconds: timeoutMs + 1000));
      final response = await request.close()
          .timeout(Duration(milliseconds: timeoutMs + 1000));

      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return (json['delay'] as num?)?.toInt() ?? -1;
      }
      return -1;
    } catch (e) {
      debugPrint('[AutoTest] Clash API error ($proxyName): $e');
      return -1;
    } finally {
      client?.close();
    }
  }

  /// TCP Ping：快速预估，VPN 未运行时使用
  Future<int> _tcpPing(ServerModel server) async {
    if (server.host == null) return -1;
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(
        server.host!,
        server.port ?? 443,
        timeout: const Duration(milliseconds: 5000),
      );
      stopwatch.stop();
      await socket.close();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  // ─────────────────────────────────────────────
  // 选择层（对标 URLTest.fast()）
  // ─────────────────────────────────────────────

  ServerModel? pickBest(List<ServerModel> servers, {int tolerance = 50}) {
    if (servers.isEmpty) return null;

    if (_fastCacheTime != null &&
        DateTime.now().difference(_fastCacheTime!).inSeconds < 10 &&
        _fastNode != null &&
        servers.any((s) => s.id == _fastNode!.id)) {
      return _fastNode;
    }

    if (_selectedOverride != null) {
      final override =
          servers.where((s) => s.id == _selectedOverride!.id).firstOrNull;
      if (override != null && (_states[override.id]?.alive ?? false)) {
        _fastNode = override;
        _fastCacheTime = DateTime.now();
        return _fastNode;
      }
      _selectedOverride = null;
    }

    ServerModel? best;
    int minDelay = 0xFFFF;
    for (final s in servers) {
      final delay = _states[s.id]?.lastDelay ?? 0xFFFF;
      if (delay < minDelay) {
        best = s;
        minDelay = delay;
      }
    }

    if (best == null) {
      _fastCacheTime = DateTime.now();
      return _fastNode;
    }

    final currentDelay = _states[_fastNode?.id]?.lastDelay ?? 0xFFFF;
    final bestDelay = _states[best.id]?.lastDelay ?? 0xFFFF;
    final currentAlive = _states[_fastNode?.id]?.alive ?? false;
    final fastNodeInList = servers.any((s) => s.id == _fastNode?.id);

    if (_fastNode == null ||
        !fastNodeInList ||
        !currentAlive ||
        currentDelay > bestDelay + tolerance) {
      _fastNode = best;
    }

    _fastCacheTime = DateTime.now();
    return _fastNode;
  }

  void forceSet(ServerModel? server) {
    _selectedOverride = server;
    _fastCacheTime = null;
    if (server == null) _fastNode = null;
  }

  /// 自动选择专用：返回"推荐使用的节点"，针对 VPN 当前节点做容差判断。
  ///
  /// - 找到延迟最低的节点 `best`
  /// - 和 [currentServerId] 的延迟对比
  /// - 当前节点 alive 且延迟 ≤ best + [tolerance] → 返回当前节点（不切换）
  /// - 当前节点死亡 / 不在列表 / 或比 best 慢超过容差 → 返回 best（切换）
  ///
  /// 调用方比较返回值和当前连接的节点 ID，不一致则触发切换。
  /// 和 [pickBest] 的区别：这里针对 VPN **实际连接**的节点做比较，
  /// 而不是 service 内部追踪的 _fastNode。
  ServerModel? pickBestWithTolerance(
    List<ServerModel> servers,
    int? currentServerId, {
    int tolerance = 50,
  }) {
    if (servers.isEmpty) return null;

    // 1. 找到绝对最快的节点
    ServerModel? best;
    int bestDelay = 0xFFFF;
    for (final s in servers) {
      if (s.id == null) continue;
      final delay = _states[s.id]?.lastDelay ?? 0xFFFF;
      if (delay < bestDelay) {
        best = s;
        bestDelay = delay;
      }
    }
    if (best == null || bestDelay >= 0xFFFF) return null; // 全挂

    // 2. 没有当前节点 → 直接用 best
    if (currentServerId == null) return best;

    // 3. 当前节点不在列表 → 用 best
    final current = servers.where((s) => s.id == currentServerId).firstOrNull;
    if (current == null) return best;

    // 4. 当前节点状态
    final currentState = _states[currentServerId];
    final currentDelay = currentState?.lastDelay ?? 0xFFFF;
    final currentAlive = currentState?.alive ?? false;

    // 5. 当前节点死了 → 必须切
    if (!currentAlive) return best;

    // 6. 容差比较
    if (currentDelay > bestDelay + tolerance) {
      return best; // 当前明显慢，切
    }
    return current; // 在容差内，保持当前
  }

  void dispose() {
    stop();
    _controller.close();
    _runCompletedController.close();
  }
}
