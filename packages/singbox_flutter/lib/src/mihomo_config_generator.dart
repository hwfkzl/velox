import 'dart:io';
import 'dart:math';

/// Platform type for Mihomo configuration generation.
enum MihomoPlatform {
  android,
  ios,
  macos,
  windows,
  linux,
}

/// Options for Mihomo configuration generation.
class MihomoConfigOptions {
  /// Platform type.
  final MihomoPlatform platform;

  /// Mixed proxy port (HTTP + SOCKS5).
  final int proxyPort;

  /// Clash API controller address.
  final String externalController;

  /// DNS servers (DoT/DoH URLs or plain IPs).
  final List<String> dnsServers;

  /// Whether to bypass LAN addresses (192.168.x.x, 10.x.x.x, etc.).
  final bool bypassLan;

  /// Package names to exclude from VPN (Android only).
  final List<String>? excludePackages;

  /// Proxy capture mode: 'tun' | 'rule' | 'global' | 'direct'
  final String proxyMode;

  /// Routing mode: 'rule' | 'global' | 'direct'
  /// When null, derived from proxyMode.
  final String? routingMode;

  const MihomoConfigOptions({
    required this.platform,
    // 17890: avoid conflict with Clash Verge (7890) and mihomo default (10808)
    this.proxyPort = 17890,
    this.externalController = '127.0.0.1:19090',
    this.dnsServers = const ['tls://8.8.8.8', 'tls://1.1.1.1'],
    this.bypassLan = true,
    this.excludePackages,
    this.proxyMode = 'rule',
    this.routingMode,
  });
}

/// Generates Mihomo (Clash Meta) YAML configuration from server data.
class MihomoConfigGenerator {
  MihomoConfigGenerator._();

  /// Detects the current platform.
  static MihomoPlatform detectPlatform() {
    if (Platform.isAndroid) return MihomoPlatform.android;
    if (Platform.isIOS) return MihomoPlatform.ios;
    if (Platform.isMacOS) return MihomoPlatform.macos;
    if (Platform.isWindows) return MihomoPlatform.windows;
    if (Platform.isLinux) return MihomoPlatform.linux;
    throw UnsupportedError('Unsupported platform');
  }

  /// 根据服务器 ID 生成在 Mihomo config 中使用的代理名称。
  /// 例如 serverId=2 → "proxy-2"
  /// V2Board 设计：vmess/vless/trojan 等各协议表独立 ID 自增，跨表 ID
  /// 会重复。所以 proxy 名字必须用 `type-id` 复合，否则 mihomo YAML
  /// 会出现重名让 Parse config error。
  ///
  /// type 不传时退化为 'proxy-{id}'（向后兼容旧调用）。
  static String proxyNameForId(int serverId, [String? type]) {
    final t = (type ?? '').toLowerCase().trim();
    return t.isEmpty ? 'proxy-$serverId' : '$t-$serverId';
  }

  /// Generates a complete Mihomo YAML configuration string.
  ///
  /// [servers] 为所有可用节点列表（全部写入 config，实现无缝切换）。
  /// [selectedServerId] 为当前选中节点的 ID（用于生成旁路规则）。
  /// 兼容旧接口：若只传 [server]，则退化为单节点模式。
  static String generate({
    Map<String, dynamic>? server,
    List<Map<String, dynamic>>? servers,
    int? selectedServerId,
    required MihomoConfigOptions options,
  }) {
    // 兼容旧的单节点调用
    final allServers = servers ?? (server != null ? [server] : []);
    assert(allServers.isNotEmpty, 'At least one server must be provided');

    // 确定当前选中节点（用于 PROXY group 排序和旁路规则）
    final activeServer = selectedServerId != null
        ? allServers.firstWhere(
            (s) => s['id'] == selectedServerId,
            orElse: () => allServers.first,
          )
        : allServers.first;
    final activeId = activeServer['id'];

    // 把选中节点排在最前面：Mihomo type:select 默认选第一个，
    // 这样初始连接时无需额外 API 调用即可使用正确节点（rule 模式）。
    final orderedServers = [
      activeServer,
      ...allServers.where((s) => s['id'] != activeId),
    ];

    // Determine effective routing mode
    final rawMode = options.routingMode ??
        (options.proxyMode == 'tun' ? 'rule' : options.proxyMode);
    final effectiveMode = rawMode;

    // Clash mode: rule / direct
    // P0：global 模式统一映射为 rule，理由：
    //   ① mode:global 下 mihomo 完全忽略 rules 段：
    //      - 节点 host 直连规则失效（防回环失效，可能形成节点→代理→节点循环）
    //      - LAN 直连规则失效
    //   ② mode:global 下 GLOBAL 是 mihomo 内置 selector，默认值不可预测
    //      （可能是 DIRECT），PUT /proxies/GLOBAL 要等 1.5s 后才调用，
    //      导致前 1-2s 流量泄漏走直连/本地 IP。
    //   ③ mode:rule 下 PROXY 组从配置加载时就默认为第一个节点（已排序到首位），
    //      无需等待 API 调用，首个连接就走正确节点。
    //   对于"全局路由"意图，只要 rules 段不下发 GEOSITE/GEOIP CN（已按
    //   effectiveMode == 'rule' 条件控制），最终落到 MATCH,PROXY，等价于 global。
    final clashMode = effectiveMode == 'direct' ? 'direct' : 'rule';

    final buf = StringBuffer();

    // ── Global settings ───────────────────────────────────────────────────
    if (options.platform == MihomoPlatform.macos ||
        options.platform == MihomoPlatform.windows ||
        options.platform == MihomoPlatform.linux) {
      buf.writeln('mixed-port: ${options.proxyPort}');
    }
    buf.writeln('allow-lan: false');
    buf.writeln('mode: $clashMode');
    buf.writeln('log-level: info');
    buf.writeln('ipv6: false');
    buf.writeln('external-controller: ${options.externalController}');
    // 关掉 selector 状态持久化:mihomo 默认 store-selected=true 会把用户上次选中
    // 的节点写进 cache.db,下次启动无视 config 里 proxies[0] 强制 ForceSet 旧选择。
    // 后果:用户点香港02 → mihomo 却复用 cache 里的 vless-21(某次误 PUT 过的节
    // 点)→ IP 全跟乱选。关掉后每次都用 config 的第一个 proxy(=用户当前选中节点)。
    buf.writeln('profile:');
    buf.writeln('  store-selected: false');
    // Geo 数据库自动更新:desktop 端 24h 拉一次;
    // Android gomobile-bind 环境下 $HOME 为空,mihomo 保存下载文件到空路径直接崩
    // (open : no such file or directory),必须关。规则里若引用 GEOSITE 但本地无库,
    // mihomo 会 fail-parse。所以 Android 上把 auto-update 关 + 不生成 geox-url。
    if (options.platform != MihomoPlatform.android) {
      buf.writeln('geo-auto-update: true');
      buf.writeln('geo-update-interval: 24');
      buf.writeln('geox-url:');
      buf.writeln("  geoip: 'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb'");
      buf.writeln("  geosite: 'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat'");
    } else {
      buf.writeln('geo-auto-update: false');
    }
    buf.writeln();

    // ── TUN ──────────────────────────────────────────────────────────────
    // Clash Verge 风格：始终输出 tun 段，enable 字段明确控制开关。
    // 热重载（PUT /configs）时 mihomo 才能正确识别 TUN 状态变更。
    if (options.proxyMode == 'tun') {
      final isAndroid = options.platform == MihomoPlatform.android;
      buf.writeln('tun:');
      buf.writeln('  enable: true');
      buf.writeln('  stack: gvisor');
      buf.writeln('  dns-hijack:');
      buf.writeln('    - any:53');
      buf.writeln('    - tcp://any:53');
      // Android 上 auto-route + auto-detect-interface 会让 sing-tun 启动
      // NetworkUpdateMonitor(netlink),Android 12+ 禁 netlink socket → tun 启动失败。
      // Kotlin 侧 VpnService.Builder 已经处理默认路由;SocketProtector 已 protect 出站;
      // 这两个 mihomo 层能力不需要,关掉才能启 tun。
      buf.writeln('  auto-route: ${isAndroid ? 'false' : 'true'}');
      buf.writeln('  auto-detect-interface: ${isAndroid ? 'false' : 'true'}');
      buf.writeln('  strict-route: false');
      buf.writeln();
    } else {
      // 非 TUN 模式：明确禁用（确保热重载时 mihomo 撤销 TUN 接口）
      buf.writeln('tun:');
      buf.writeln('  enable: false');
      buf.writeln('  stack: gvisor');
      buf.writeln('  auto-route: true');
      buf.writeln('  auto-detect-interface: true');
      buf.writeln();
    }

    // ── Sniffer (TLS SNI / HTTP Host / QUIC SNI 嗅探) ─────────────────────
    // TUN 模式下，老旧应用直接用 IP 连接时 metadata 缺 Host，
    // GEOSITE 规则无法命中只能靠 GEOIP 兜底。sniffer 在 TLS ClientHello /
    // HTTP Header / QUIC Initial 包里嗅出真实域名回填 metadata.Host，
    // 让 GEOSITE 路径生效，分流准确度↑。
    if (effectiveMode == 'rule') {
      buf.writeln('sniffer:');
      buf.writeln('  enable: true');
      buf.writeln('  parse-pure-ip: true');
      buf.writeln('  override-destination: false');
      buf.writeln('  sniff:');
      buf.writeln('    TLS:');
      buf.writeln('      ports: [443, 8443]');
      buf.writeln('    HTTP:');
      buf.writeln('      ports: [80, 8080-8880]');
      buf.writeln('      override-destination: false');
      buf.writeln('    QUIC:');
      buf.writeln('      ports: [443]');
      // 跳过已知会误伤的域名（IoT/推送协议）
      buf.writeln('  skip-domain:');
      buf.writeln("    - 'Mijia Cloud'");
      buf.writeln("    - '+.push.apple.com'");
      buf.writeln();
    }

    // ── DNS ───────────────────────────────────────────────────────────────
    buf.writeln('dns:');
    buf.writeln('  enable: true');
    buf.writeln('  ipv6: false');
    // TUN 模式始终使用 fake-ip：redir-host 会让 DNS 查询也走 TUN→代理，
    // 而 fake-ip 直接在 mihomo 内部解析，速度快且无循环问题。
    if (effectiveMode == 'rule' || options.proxyMode == 'tun') {
      // ── DNS 解析子系统：对齐 Clash Verge Rev 默认（src-tauri/src/utils/init.rs）──
      //   CN/国外分流交给路由规则（mode: rule）；DNS 只负责解析，不再做 geosite
      //   分域名 + fallback 防污染那一套（已移除 nameserver-policy / fallback）。
      //   respect-rules:false → DNS 查询直连、不等代理就绪 → 启动更稳。
      //   注：未设 listen（CV 设 :53）——代理模式 mihomo 以普通用户运行，绑定特权
      //   端口 53 会失败；TUN 用 dns-hijack 直接喂内部解析器，也无需 listen。
      buf.writeln('  enhanced-mode: fake-ip');
      buf.writeln('  fake-ip-range: 198.18.0.1/16');
      buf.writeln('  fake-ip-filter-mode: blacklist');
      buf.writeln('  prefer-h3: false');
      buf.writeln('  respect-rules: false');
      buf.writeln('  use-hosts: false');
      buf.writeln('  use-system-hosts: false');
      buf.writeln('  fake-ip-filter:');
      buf.writeln("    - '*.lan'");
      buf.writeln("    - '*.local'");
      buf.writeln("    - '*.arpa'");
      buf.writeln("    - 'time.*.com'");
      buf.writeln("    - 'ntp.*.com'");
      buf.writeln("    - '+.market.xiaomi.com'");
      buf.writeln("    - 'localhost.ptlogin2.qq.com'");
      buf.writeln("    - '*.msftncsi.com'");
      buf.writeln("    - 'www.msftconnecttest.com'");
      // 引导 DNS（system + 纯 IP，用于解析 DoH 服务器自身域名）。
      // 逐条对齐 Clash Verge 默认（含 IPv6 引导项；ipv6:false 下不会被使用，仅为一致）。
      buf.writeln('  default-nameserver:');
      buf.writeln('    - system');
      buf.writeln('    - 223.6.6.6');
      buf.writeln('    - 8.8.8.8');
      buf.writeln('    - 2400:3200::1');
      buf.writeln('    - 2001:4860:4860::8888');
      // 主 DNS：混合（与 CV 一致），CN/国外分流交给路由规则而非 DNS
      buf.writeln('  nameserver:');
      buf.writeln('    - 8.8.8.8');
      buf.writeln('    - https://doh.pub/dns-query');
      buf.writeln('    - https://dns.alidns.com/dns-query');
      // CV 默认不用 fallback（留空）
      buf.writeln('  fallback: []');
      // 代理节点域名解析（直连，破解析回环）
      buf.writeln('  proxy-server-nameserver:');
      buf.writeln('    - https://doh.pub/dns-query');
      buf.writeln('    - https://dns.alidns.com/dns-query');
      buf.writeln('    - tls://223.5.5.5');
      // fallback 为空时此段不生效，仅为与 CV 默认结构一致而保留
      buf.writeln('  fallback-filter:');
      buf.writeln('    geoip: true');
      buf.writeln('    geoip-code: CN');
      buf.writeln('    ipcidr:');
      buf.writeln('      - 240.0.0.0/4');
      buf.writeln('      - 0.0.0.0/32');
      buf.writeln('    domain:');
      buf.writeln("      - '+.google.com'");
      buf.writeln("      - '+.facebook.com'");
      buf.writeln("      - '+.youtube.com'");
    } else {
      // global / direct 模式：redir-host 简单 DNS，不做分流
      buf.writeln('  enhanced-mode: redir-host');
      buf.writeln('  default-nameserver:');
      buf.writeln('    - 223.5.5.5');
      buf.writeln('    - 119.29.29.29');
      buf.writeln('  nameserver:');
      buf.writeln('    - https://dns.alidns.com/dns-query');
      buf.writeln('    - https://doh.pub/dns-query');
    }
    buf.writeln();

    // ── Proxies（所有节点全部写入）────────────────────────────────────────
    buf.writeln('proxies:');
    for (final srv in orderedServers) {
      final id = srv['id'] as int?;
      final type = srv['type'] as String?;
      final entry = _buildProxyEntry(srv);
      // 用 <type>-<id> 命名：跨协议表 ID 重复时不会冲突
      entry['name'] = id != null ? proxyNameForId(id, type) : 'proxy';
      _writeProxyEntry(buf, entry);
    }
    buf.writeln();

    // ── Proxy Groups ──────────────────────────────────────────────────────
    // orderedServers 保证选中节点排第一：Mihomo type:select 默认选首项，
    // rule 模式下初始连接无需 API 调用即可使用正确节点。
    buf.writeln('proxy-groups:');
    buf.writeln('  - name: PROXY');
    buf.writeln('    type: select');
    buf.writeln('    proxies:');
    for (final srv in orderedServers) {
      final id = srv['id'] as int?;
      final type = srv['type'] as String?;
      final name = id != null ? proxyNameForId(id, type) : 'proxy';
      buf.writeln('      - $name');
    }
    // REJECT 加入 PROXY selector — Kill Switch 用:Kotlin 侧 disconnect 时 PUT
    // /proxies/PROXY {"name":"REJECT"},mihomo 把所有流量丢弃,tun 保留,用户
    // 真实 IP 不泄漏。用户"彻底关闭"才 stop mihomo + close tun。
    if (options.platform == MihomoPlatform.android) {
      buf.writeln('      - REJECT');
    }
    buf.writeln();

    // ── Rule Providers ───────────────────────────────────────────────────
    // 远程规则集,从 jsDelivr CDN 拉取。
    // Android gomobile-bind 环境 $HOME 空,mihomo 存 ./ruleset/*.txt 时保存路径
    // 拼不出 → open("") 崩。Android 端跳过 rule-providers(反正规则段也跳过 RULE-SET)。
    if (effectiveMode == 'rule' && options.platform != MihomoPlatform.android) {
      buf.writeln('rule-providers:');
      // 广告/追踪屏蔽（数千条域名+IP）
      buf.writeln('  reject:');
      buf.writeln('    type: http');
      buf.writeln('    behavior: domain');
      buf.writeln('    format: text');
      buf.writeln("    url: 'https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt'");
      buf.writeln('    interval: 86400');
      buf.writeln('    path: ./ruleset/reject.txt');
      // GFW 封锁名单
      buf.writeln('  gfw:');
      buf.writeln('    type: http');
      buf.writeln('    behavior: domain');
      buf.writeln('    format: text');
      buf.writeln("    url: 'https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/gfw.txt'");
      buf.writeln('    interval: 86400');
      buf.writeln('    path: ./ruleset/gfw.txt');
      buf.writeln();
    }

    // ── Rules ─────────────────────────────────────────────────────────────
    // 规则顺序（参照 Clash Verge default 和行业标准）：
    //   ① 代理节点 IP/域名 → DIRECT（防路由回环，最高优先级）
    //   ② LAN / 私有地址  → DIRECT,no-resolve
    //   ③ 广告/追踪屏蔽 → REJECT
    //   ④ 国内服务细分 → DIRECT
    //   ⑤ 必走代理细分 → PROXY
    //   ⑥ GEOSITE,CN   → DIRECT（域名规则在 GEOIP 前：无需 DNS 解析，速度快）
    //   ⑦ GEOIP,CN     → DIRECT,no-resolve（IP 兜底）
    //   ⑧ MATCH        → PROXY/DIRECT
    buf.writeln('rules:');

    // ① 代理节点服务器地址全部直连（防路由回环）
    //    IP-CIDR 加 no-resolve：fake-ip 模式下不触发多余 DNS 查询
    final bypassedHosts = <String>{};
    for (final srv in allServers) {
      final host = srv['host'] as String? ?? '';
      if (host.isEmpty || bypassedHosts.contains(host)) continue;
      bypassedHosts.add(host);
      final isIp = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host);
      if (isIp) {
        buf.writeln('  - IP-CIDR,$host/32,DIRECT,no-resolve');
      } else {
        buf.writeln('  - DOMAIN,$host,DIRECT');
      }
    }

    // ② LAN / 私有地址直连
    //    全部加 no-resolve：fake-ip 模式下私有地址不需要 DNS 解析
    if (options.bypassLan) {
      buf.writeln('  - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve');
      buf.writeln('  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve');
      buf.writeln('  - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve');
      buf.writeln('  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve');
      buf.writeln('  - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve');
      buf.writeln('  - IP-CIDR,169.254.0.0/16,DIRECT,no-resolve');
    }

    if (effectiveMode == 'rule') {
      final isAndroid = options.platform == MihomoPlatform.android;
      // Android geo 数据已在 assets 里,SingboxCore.ensureGeoData 会 copy 到 filesDir
      // 并 setHomeDir 让 mihomo 找到 → CN 分流生效。RULE-SET(reject/gfw)不打包,
      // 走 Loyalsoldier 需要外部下载,略过。
      if (isAndroid) {
        // Android 精简版:优先域名分流(fake-ip 下 GEOIP,CN,no-resolve 会跳过 IP 解析)
        buf.writeln('  - GEOSITE,category-ads-all,REJECT');
        buf.writeln('  - GEOSITE,apple-cn,DIRECT');
        buf.writeln('  - GEOSITE,microsoft@cn,DIRECT');
        buf.writeln('  - GEOSITE,steam@cn,DIRECT');
        buf.writeln('  - GEOSITE,category-games@cn,DIRECT');
        buf.writeln('  - GEOSITE,telegram,PROXY');
        buf.writeln('  - GEOSITE,openai,PROXY');
        buf.writeln('  - GEOSITE,github,PROXY');
        buf.writeln('  - GEOSITE,google,PROXY');
        buf.writeln('  - GEOSITE,CN,DIRECT');
        buf.writeln('  - GEOIP,CN,DIRECT,no-resolve');
      } else {
        buf.writeln('  - RULE-SET,reject,REJECT');
        buf.writeln('  - GEOSITE,category-ads-all,REJECT');
        buf.writeln('  - GEOSITE,apple-cn,DIRECT');
        buf.writeln('  - GEOSITE,microsoft@cn,DIRECT');
        buf.writeln('  - GEOSITE,steam@cn,DIRECT');
        buf.writeln('  - GEOSITE,category-games@cn,DIRECT');
        buf.writeln('  - GEOSITE,telegram,PROXY');
        buf.writeln('  - GEOSITE,openai,PROXY');
        buf.writeln('  - GEOSITE,github,PROXY');
        buf.writeln('  - GEOSITE,google,PROXY');
        buf.writeln('  - RULE-SET,gfw,PROXY');
        buf.writeln('  - GEOSITE,CN,DIRECT');
        buf.writeln('  - GEOIP,CN,DIRECT,no-resolve');
      }
    }

    final finalTarget = effectiveMode == 'direct' ? 'DIRECT' : 'PROXY';
    buf.writeln('  - MATCH,$finalTarget');

    return buf.toString();
  }

  /// Writes a proxy entry map as indented YAML lines.
  /// Matches the official Mihomo config.yaml format exactly.
  static void _writeProxyEntry(
      StringBuffer buf, Map<String, dynamic> entry) {
    bool first = true;
    for (final kv in entry.entries) {
      if (kv.value == null) continue;
      final prefix = first ? '  - ' : '    ';
      if (first) first = false;

      final v = kv.value;
      if (v is Map<String, dynamic>) {
        // Block mapping: key on its own line, values indented below
        buf.writeln('$prefix${kv.key}:');
        for (final inner in v.entries) {
          if (inner.value == null) continue;
          final iv = inner.value;
          if (iv is List) {
            buf.writeln('      ${inner.key}:');
            for (final item in iv) {
              buf.writeln('        - ${_yamlScalar(item)}');
            }
          } else {
            buf.writeln('      ${inner.key}: ${_yamlScalar(iv)}');
          }
        }
      } else if (v is List) {
        if (v.isEmpty) {
          buf.writeln('$prefix${kv.key}: []');
        } else {
          buf.writeln('$prefix${kv.key}:');
          for (final item in v) {
            buf.writeln('      - ${_yamlScalar(item)}');
          }
        }
      } else {
        buf.writeln('$prefix${kv.key}: ${_yamlScalar(v)}');
      }
    }
  }

  /// P1-4 + P2-2 修复:统一 scalar 输出,单引号包裹时把内部 ' 双写为 '' 转义。
  /// 之前 `'don't-guess'` 会被 YAML parser 在第一个内引号截断,导致 mihomo 拒整份 config。
  /// YAML 1.2 spec:single-quoted scalar 里 ' 用 '' 表示。
  static String _yamlScalar(dynamic v) {
    if (v is String) {
      if (_needsQuoting(v)) {
        final escaped = v.replaceAll("'", "''");
        return "'$escaped'";
      }
      return v;
    }
    return '$v';
  }

  /// Returns true if a YAML string value needs quoting.
  static bool _needsQuoting(String v) {
    if (v.isEmpty) return true;
    // Quote if contains YAML special characters
    return v.contains(': ') ||
        v.startsWith('#') ||
        v.contains("'") ||
        v.startsWith('{') ||
        v.startsWith('[') ||
        v.startsWith('*') ||
        v.startsWith('&');
  }

  /// Builds a proxy entry Map for Mihomo proxies section.
  static Map<String, dynamic> _buildProxyEntry(
      Map<String, dynamic> server) {
    // effective_type 由上层（vpn_bloc._serverToConfigMap）解包 v2node 容器 +
    // 推断 hysteria v1/v2 后设置，mihomo switch 必须用解包后的真实协议（'vmess'/'trojan'/...）
    // 才能识别——直接用 server['type']（保留 'v2node' 等原始值供命名）会撞 UnsupportedError。
    // 未提供 effective_type 时回退 type，兼容旧调用方。
    final type =
        ((server['effective_type'] ?? server['type']) as String?)?.toLowerCase()
            ?? 'shadowsocks';
    final host = server['host'] as String? ?? '';
    final port = _parsePort(server['mport']) ??
        _parsePort(server['port']) ??
        _parsePort(server['server_port']) ??
        443;
    Map<String, dynamic> _toStrMap(dynamic v) =>
        v == null ? {} : Map<String, dynamic>.from(v as Map);
    final protocolSettings = _toStrMap(server['protocol_settings']);
    final networkSettings  = _toStrMap(server['network_settings']);
    final tlsSettings      = _toStrMap(server['tls_settings']);
    final obfsSettings     = _toStrMap(server['obfs_settings']);
    final network = server['network'] as String?;
    final tlsEnabled = server['tls'] == '1' ||
        server['tls'] == 1 ||
        server['tls'] == true ||
        server['tls'] == '2' ||
        server['tls'] == 2;
    final isReality = server['tls'] == '2' || server['tls'] == 2;
    final flow = server['flow'] as String?;
    final cipher = server['cipher'] as String?;

    final serverName = tlsSettings['server_name'] as String? ??
        tlsSettings['serverName'] as String? ??
        host;
    final insecure = tlsSettings['allow_insecure'] == true ||
        tlsSettings['allowInsecure'] == true ||
        tlsSettings['allow_insecure'] == 1 ||
        tlsSettings['allowInsecure'] == 1;
    final disableSni = tlsSettings['disable_sni'] == true ||
        tlsSettings['disable_sni'] == 1;
    final alpnList =
        (tlsSettings['alpn'] as List?)?.cast<String>();
    final realityPublicKey = tlsSettings['public_key'] as String?;
    final realityShortId = tlsSettings['short_id'] as String?;
    final fingerprint =
        tlsSettings['fingerprint'] as String? ?? 'chrome';

    final wsPath = networkSettings['path'] as String? ?? '/';
    final wsHost = networkSettings['headers']?['Host'] as String?;
    final grpcServiceName = networkSettings['serviceName'] as String? ??
        networkSettings['service_name'] as String?;

    switch (type) {
      case 'shadowsocks':
        final entry = <String, dynamic>{
          'name': 'proxy',
          'type': 'ss',
          'server': host,
          'port': port,
          'cipher': cipher ?? 'aes-256-gcm',
          'password': protocolSettings['password'] as String? ?? '',
        };
        // Obfs plugin
        if (obfsSettings.isNotEmpty || server['obfs'] == 'http') {
          final obfsHost = obfsSettings['host'] as String? ??
              server['obfs-host'] as String? ?? '';
          entry['plugin'] = 'obfs';
          entry['plugin-opts'] = {
            'mode': 'http',
            'host': obfsHost,
          };
        }
        return entry;

      case 'vmess':
        final net = network?.toLowerCase() ?? 'tcp';
        final entry = <String, dynamic>{
          'name': 'proxy',
          'type': 'vmess',
          'server': host,
          'port': port,
          'uuid': protocolSettings['uuid'] as String? ??
              protocolSettings['id'] as String? ?? '',
          'alterId': protocolSettings['alter_id'] as int? ??
              protocolSettings['alterId'] as int? ?? 0,
          'cipher': cipher ?? 'auto',
          'tls': tlsEnabled,
          if (tlsEnabled) 'servername': serverName,
          if (tlsEnabled && insecure) 'skip-cert-verify': true,
          if (tlsEnabled && alpnList != null && alpnList.isNotEmpty)
            'alpn': alpnList,
          'network': net,
        };
        _addNetworkOpts(entry, net, wsPath, wsHost, grpcServiceName);
        return entry;

      case 'vless':
        final net = network?.toLowerCase() ?? 'tcp';
        final effectiveFlow =
            (tlsEnabled && (network == null || net == 'tcp'))
                ? flow
                : null;
        final entry = <String, dynamic>{
          'name': 'proxy',
          'type': 'vless',
          'server': host,
          'port': port,
          'uuid': protocolSettings['uuid'] as String? ??
              protocolSettings['id'] as String? ?? '',
          'network': net,
          'tls': tlsEnabled,
          'udp': true,
          if (tlsEnabled) 'servername': serverName,
          if (tlsEnabled && insecure) 'skip-cert-verify': true,
          if (tlsEnabled && alpnList != null && alpnList.isNotEmpty)
            'alpn': alpnList,
          if (effectiveFlow != null) 'flow': effectiveFlow,
        };
        if (isReality && realityPublicKey != null) {
          entry['reality-opts'] = {
            'public-key': realityPublicKey,
            if (realityShortId != null && realityShortId.isNotEmpty)
              'short-id': realityShortId,
          };
          entry['client-fingerprint'] = fingerprint;
        }
        // 后量子加密（mlkem768x25519plus 等，v2node 引入；原生 vless 表 update.sql 也已
        // 添加 encryption/encryption_settings 列，所以这条路径同时覆盖原生 vless）。
        // 对齐后端 ClashMeta::buildVless 拼接格式：'algorithm.mode.rtt[.client_padding].password'。
        // 用 ?.toString() 防御性兜底——admin 偶尔把字段填成数字（DB text 列不强类型），
        // `as String?` 会抛 CastError 导致整个 config 生成失败影响所有节点。
        final encAlgorithm = server['encryption']?.toString();
        final encSettings = _toStrMap(server['encryption_settings']);
        if (encAlgorithm != null &&
            encAlgorithm.isNotEmpty &&
            encSettings.isNotEmpty) {
          final mode = encSettings['mode']?.toString() ?? 'native';
          final rtt = encSettings['rtt']?.toString() ?? '1rtt';
          final clientPadding = encSettings['client_padding']?.toString();
          final password = encSettings['password']?.toString() ?? '';
          final buf = StringBuffer()
            ..write(encAlgorithm)
            ..write('.')
            ..write(mode)
            ..write('.')
            ..write(rtt);
          if (clientPadding != null && clientPadding.isNotEmpty) {
            buf..write('.')..write(clientPadding);
          }
          buf..write('.')..write(password);
          entry['encryption'] = buf.toString();
        }
        _addNetworkOpts(entry, net, wsPath, wsHost, grpcServiceName);
        return entry;

      case 'trojan':
        final net = network?.toLowerCase() ?? 'tcp';
        final entry = <String, dynamic>{
          'name': 'proxy',
          'type': 'trojan',
          'server': host,
          'port': port,
          'password': protocolSettings['password'] as String? ?? '',
          'sni': serverName,
          if (insecure) 'skip-cert-verify': true,
          if (alpnList != null && alpnList.isNotEmpty) 'alpn': alpnList,
          'network': net,
        };
        _addNetworkOpts(entry, net, wsPath, wsHost, grpcServiceName);
        return entry;

      case 'hysteria':
        return {
          'name': 'proxy',
          'type': 'hysteria',
          'server': host,
          'port': port,
          'auth-str': protocolSettings['auth_str'] as String? ??
              protocolSettings['auth'] as String? ?? '',
          'protocol': 'udp',
          'up': '${protocolSettings['up_mbps'] ?? protocolSettings['up'] ?? 100} Mbps',
          'down': '${protocolSettings['down_mbps'] ?? protocolSettings['down'] ?? 100} Mbps',
          'sni': serverName,
          if (insecure) 'skip-cert-verify': true,
          if (alpnList != null && alpnList.isNotEmpty) 'alpn': alpnList,
          if (obfsSettings['password'] != null)
            'obfs': obfsSettings['password'] as String,
        };

      case 'hysteria2':
      case 'hy2':
        final entry = <String, dynamic>{
          'name': 'proxy',
          'type': 'hysteria2',
          'server': host,
          'port': port,
          'password': protocolSettings['password'] as String? ?? '',
          'sni': serverName,
          if (insecure) 'skip-cert-verify': true,
          if (alpnList != null && alpnList.isNotEmpty) 'alpn': alpnList,
        };
        if (obfsSettings['password'] != null) {
          entry['obfs'] = obfsSettings['type'] as String? ?? 'salamander';
          entry['obfs-password'] = obfsSettings['password'] as String;
        }
        return entry;

      case 'tuic':
        return {
          'name': 'proxy',
          'type': 'tuic',
          'server': host,
          'port': port,
          'uuid': protocolSettings['uuid'] as String? ?? '',
          'password': protocolSettings['password'] as String? ?? '',
          'sni': serverName,
          if (insecure) 'skip-cert-verify': true,
          'alpn': (alpnList != null && alpnList.isNotEmpty) ? alpnList : ['h3'],
          if (protocolSettings['congestion_control'] != null)
            'congestion-controller':
                protocolSettings['congestion_control'] as String,
          if (protocolSettings['udp_relay_mode'] != null)
            'udp-relay-mode': protocolSettings['udp_relay_mode'] as String,
          if (disableSni) 'disable-sni': true,
          if (protocolSettings['zero_rtt_handshake'] == true ||
              protocolSettings['zero_rtt_handshake'] == 1)
            'reduce-rtt': true,
        };

      case 'anytls':
        // Mihomo 自 1.19.0 起支持 AnyTLS，字段格式与后端 ClashMeta 输出保持一致
        return {
          'name': 'proxy',
          'type': 'anytls',
          'server': host,
          'port': port,
          'password': protocolSettings['password'] as String? ?? '',
          'client-fingerprint': fingerprint,
          'udp': true,
          'sni': serverName,
          'alpn': (alpnList != null && alpnList.isNotEmpty)
              ? alpnList
              : ['h2', 'http/1.1'],
          if (insecure) 'skip-cert-verify': true,
        };

      default:
        throw UnsupportedError('Unsupported protocol type: $type');
    }
  }

  /// Adds WebSocket / gRPC / HTTP network options to proxy entry.
  static void _addNetworkOpts(
    Map<String, dynamic> entry,
    String network,
    String wsPath,
    String? wsHost,
    String? grpcServiceName,
  ) {
    switch (network) {
      case 'ws':
      case 'websocket':
        entry['network'] = 'ws';
        final wsOpts = <String, dynamic>{'path': wsPath};
        if (wsHost != null && wsHost.isNotEmpty) {
          wsOpts['headers'] = {'Host': wsHost};
        }
        entry['ws-opts'] = wsOpts;
        break;
      case 'grpc':
        entry['network'] = 'grpc';
        entry['grpc-opts'] = {
          'grpc-service-name': grpcServiceName ?? '',
        };
        break;
      case 'http':
      case 'h2':
        entry['network'] = 'h2';
        if (wsHost != null) {
          entry['h2-opts'] = {
            'host': [wsHost],
            'path': wsPath,
          };
        }
        break;
      default:
        // tcp — no extra options needed
        break;
    }
  }

  /// Parses port value, supports int or range string (e.g. "8000-9000").
  static int? _parsePort(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      if (value.contains('-')) {
        final parts = value.split('-');
        final start = int.tryParse(parts[0].trim()) ?? 0;
        final end = int.tryParse(parts[1].trim()) ?? 0;
        if (start > 0 && end >= start) {
          return start + Random().nextInt(end - start + 1);
        }
      }
      return int.tryParse(value.trim());
    }
    return null;
  }
}
