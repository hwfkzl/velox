/// 日志落盘过滤器 —— 让 client.log 只保留有排障价值的行。
///
/// 规则(从最先命中的开始):
/// 1. **level 底线**:E / W / F 全 tag 无条件保留
/// 2. **tag 黑名单**:命中 [dropRules] 里的 pattern 立即丢
/// 3. **tag 白名单**:命中 [keepRules] 里的 pattern 保留
/// 4. **RemoteConfig I 级 startup-anchor**:每个新 session 前 4 条 [I] [RemoteConfig] 保留
///    (启动引导链 —— OSS → API endpoint 拿到过程),之后 [I] 全丢
/// 5. **未命名 tag / print / 未识别 message**:默认保留(保守,防漏关键)
///
/// 数据源自 workflow 深度调研,基于对 5325 行真实日志的 tag/message 分析。
/// 精简目标:Dart 日志从 ~2200 行 → ~830 行。控制台输出不受影响。
library;

class LogFilter {
  LogFilter._();

  // ─── 通用底线 ─────────────────────────────────────────
  static const Set<String> _keepLevels = {'E', 'W', 'F'};

  // ─── VpnBloc:状态机关键跃迁 + warning 保留 ─────────────
  static final List<RegExp> _vpnBlocKeep = [
    RegExp(r'=== VpnBloc\._onConnectRequested (START|END)'),
    RegExp(r'VpnBloc: TUN (routing|on|off)'),
    RegExp(r'VpnBloc: proxyMode ='),
    RegExp(r'VpnBloc: routingMode ='),
    RegExp(r'VpnBloc: current server ='),
    RegExp(r'VpnBloc: server (host|port|name) ='),
    RegExp(r'VpnBloc: traffic detected'),
    RegExp(r'VpnBloc: (_initService called|mihomoService initialized|subscribed to service)'),
    RegExp(r'VpnBloc: current state\.status ='),
  ];
  static final List<RegExp> _vpnBlocDrop = [
    RegExp(r'VpnBloc: state emitted'),
    RegExp(r'VpnBloc: connect call completed'),
    RegExp(r'VpnBloc: calling mihomoService\.connect'),
    RegExp(r'VpnBloc: emitting connecting status'),
    RegExp(r'VpnBloc: serverConfig keys ='),
    RegExp(r'VpnBloc: including \d+ servers in config'),
    RegExp(r'VpnBloc: user uuid ='),
  ];

  // ─── ApiClient:除 [E] 全丢(268 个 debug 请求追踪) ──
  // 特例:登录相关请求即使 debug 也留(诊断"点了登录没反应"时需要)
  static final List<RegExp> _apiClientKeep = [
    RegExp(r'(POST|GET).*/passport/auth/'), // 登录/注册/找回密码
    RegExp(r' 5\d\d '), // 5xx 服务端错误响应
  ];

  // ─── print(AutoTest):砍空转轮询 ───────────────────────
  static final List<RegExp> _autoTestDrop = [
    RegExp(r'\[AutoTest\] ⏭ 跳过 runOnce'),
  ];

  /// 检查是否放行落盘。sessionInfoCount 由调用方维护(用于 startup-anchor)。
  static bool shouldKeep({
    required String level,
    required String tag,
    required String message,
    required Map<String, int> sessionInfoCount,
  }) {
    // ① level 底线:E/W/F 全放行
    if (_keepLevels.contains(level)) return true;

    // ② 按 tag 分派
    switch (tag) {
      case 'VpnBloc':
        for (final r in _vpnBlocDrop) {
          if (r.hasMatch(message)) return false;
        }
        // 白名单命中 keep,否则默认 drop(VpnBloc 已知 dropRules 覆盖大头,
        // 剩余未识别的可能是新加的日志,保守 keep)
        for (final r in _vpnBlocKeep) {
          if (r.hasMatch(message)) return true;
        }
        // fallthrough:未识别的 I 级 VpnBloc 也 keep(保守)
        return true;

      case 'RemoteConfig':
        // I 级走 startup-anchor:每个 session 前 4 条留,之后全丢
        if (level == 'I') {
          final n = (sessionInfoCount[tag] ?? 0) + 1;
          sessionInfoCount[tag] = n;
          return n <= 4;
        }
        // D 级(如"已从缓存加载"降级路径)全留
        return true;

      case 'ApiClient':
        // 除 E 已上面放行,剩下的 D/I 只留登录 + 5xx
        for (final r in _apiClientKeep) {
          if (r.hasMatch(message)) return true;
        }
        return false;

      case 'print':
        // AutoTest 空转轮询丢弃
        for (final r in _autoTestDrop) {
          if (r.hasMatch(message)) return false;
        }
        return true;

      case 'Feedback':
        // 反馈上传自身事件量小(4 行/次)全留
        return true;
    }

    // ③ 未识别 tag:默认保守 keep
    return true;
  }
}
