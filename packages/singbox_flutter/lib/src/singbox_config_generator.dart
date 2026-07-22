import 'dart:convert';

/// sing-box JSON 配置生成器(Android 端用,跟 macOS 的 MihomoConfigGenerator 平行)。
///
/// **协议覆盖**:VLESS(含 Reality + XTLS Vision)/ Trojan / AnyTLS / Shadowsocks
/// / VMess / Hysteria2 — 主流商业机场协议全覆盖。
///
/// 输入跟 MihomoConfigGenerator 同源(都是 VpnBloc._serverToConfigMap 出来的 Map),
/// 输出是 sing-box 标准 JSON 字符串。
class SingBoxConfigGenerator {
  /// proxy outbound tag 命名:`<type>-<id>`,跟 MihomoConfigGenerator.proxyNameForId 对齐。
  /// 跨平台一致,vpn_bloc 切节点 / 自动测速逻辑不用关心平台。
  static String proxyNameForId(int serverId, [String? type]) {
    final t = (type ?? '').toLowerCase();
    return t.isNotEmpty ? '$t-$serverId' : 'proxy-$serverId';
  }

  /// 主入口:单节点 or 多节点都走这里。
  static String generate({
    Map<String, dynamic>? server,
    List<Map<String, dynamic>>? servers,
    int? selectedServerId,
    String proxyMode = 'rule',
  }) {
    final allServers = servers ?? (server != null ? [server] : []);
    if (allServers.isEmpty) {
      throw ArgumentError('SingBoxConfigGenerator: empty server list');
    }

    final activeServer = (selectedServerId != null)
        ? allServers.firstWhere(
            (s) => s['id'] == selectedServerId,
            orElse: () => allServers.first,
          )
        : allServers.first;

    final outbounds = <Map<String, dynamic>>[];
    final proxyTags = <String>[];

    // 节点 outbounds
    for (final s in allServers) {
      final outbound = _buildOutbound(s);
      if (outbound != null) {
        outbounds.add(outbound);
        proxyTags.add(outbound['tag'] as String);
      }
    }

    // selector outbound — 跟 mihomo 的 PROXY group 等价
    final selectedTag = proxyNameForId(
      activeServer['id'] as int,
      (activeServer['type'] as String?) ?? (activeServer['effective_type'] as String?),
    );
    outbounds.insert(0, {
      'type': 'selector',
      'tag': 'PROXY',
      'outbounds': proxyTags,
      'default': selectedTag,
    });

    // 基础 outbounds(sing-box 1.13+ 删了 block/dns special outbound,只留 direct)
    outbounds.add({'type': 'direct', 'tag': 'direct'});

    // Android 没有系统代理这种概念,VpnService 只能用 TUN(走 VpnService.Builder 建虚拟网卡)。
    // 所以 Android 无视 proxy_mode='rule'/'tun',永远输出 TUN inbound,否则就没流量入口。
    final isTun = true;

    final config = {
      'log': {'level': 'debug', 'timestamp': true},  // 临时开 debug 诊断流量不通
      'dns': _buildDns(isTun),
      'inbounds': [_buildTunInbound()],
      'outbounds': outbounds,
      'route': _buildRoute(),
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:19090',
          'default_mode': 'rule',
        },
      },
    };

    return jsonEncode(config);
  }

  // ─── DNS ─────────────────────────────────────────────────────────
  // sing-box 1.14 DNS 设计原则:
  // - DNS 不能走 PROXY(否则死循环:解析节点域名 → 走 PROXY → 又要解析节点)
  // - sing-box 1.14 不允许 detour 到空 direct outbound(报 "makes no sense")
  // → 用 type=local:直接走 Android OS 系统 resolver(getaddrinfo),绕开 sing-box outbound 路由
  static Map<String, dynamic> _buildDns(bool isTun) => {
        'servers': [
          {
            'tag': 'dns-default',
            'type': 'local',  // 系统 resolver,不走 outbound
          },
        ],
        'final': 'dns-default',
        'strategy': 'ipv4_only',
      };

  // ─── TUN inbound ─────────────────────────────────────────────────
  // sing-box 1.13+ 删了 inbound 里的 sniff/sniff_override_destination/platform 等 legacy 字段,
  // sniff 已迁移到 route.rules 里用 action 形式(_buildRoute 里加 sniff rule)。
  static Map<String, dynamic> _buildTunInbound() => {
        'type': 'tun',
        'tag': 'tun-in',
        'interface_name': 'tun0',
        'address': ['172.19.0.1/30'],
        'mtu': 1500,
        'auto_route': true,
        'strict_route': false,
        'stack': 'system',
      };

  // ─── Route(sing-box 1.13+ 用 rule actions 替代 special outbound) ──
  static Map<String, dynamic> _buildRoute() => {
        'rules': [
          // DNS 流量截获到 sing-box 内置 DNS server(不再用 "outbound": "dns-out")
          {'protocol': 'dns', 'action': 'hijack-dns'},
          // 私有 IP 走直连
          {'ip_is_private': true, 'outbound': 'direct'},
        ],
        'auto_detect_interface': true,
        'final': 'PROXY',
      };

  // ─── 节点 outbound 构造分发 ───────────────────────────────────────
  static Map<String, dynamic>? _buildOutbound(Map<String, dynamic> s) {
    final id = s['id'] as int?;
    if (id == null) return null;
    final rawType = (s['type'] as String?)?.toLowerCase() ?? '';
    final effectiveType = (s['effective_type'] as String?)?.toLowerCase() ?? rawType;
    final tag = proxyNameForId(id, rawType);

    final host = (s['host'] as String?) ?? '';
    final port = _firstPort(s);
    if (host.isEmpty || port == 0) return null;

    switch (effectiveType) {
      case 'vless':
        return _buildVless(s, tag, host, port);
      case 'trojan':
        return _buildTrojan(s, tag, host, port);
      case 'anytls':
        return _buildAnyTls(s, tag, host, port);
      case 'shadowsocks':
      case 'ss':
        return _buildShadowsocks(s, tag, host, port);
      case 'vmess':
        return _buildVmess(s, tag, host, port);
      case 'hysteria2':
      case 'hy2':
        return _buildHysteria2(s, tag, host, port);
      default:
        return null;
    }
  }

  /// port 字段优先级:port → first(mport.split(',')) → server_port
  static int _firstPort(Map<String, dynamic> s) {
    final port = s['port'];
    if (port is int && port > 0) return port;
    if (port is String) {
      final n = int.tryParse(port);
      if (n != null && n > 0) return n;
    }
    final mport = s['mport'] as String?;
    if (mport != null && mport.isNotEmpty) {
      final first = mport.split(',').first.split('-').first;
      final n = int.tryParse(first);
      if (n != null && n > 0) return n;
    }
    final serverPort = s['server_port'];
    if (serverPort is int && serverPort > 0) return serverPort;
    return 0;
  }

  // ─── VLESS(支持 Reality + XTLS Vision) ───────────────────────────
  static Map<String, dynamic> _buildVless(
      Map<String, dynamic> s, String tag, String host, int port) {
    final ps = (s['protocol_settings'] as Map?) ?? {};
    final tls = (s['tls_settings'] as Map?) ?? {};
    final network = (s['network'] as String?) ?? 'tcp';
    final ns = (s['network_settings'] as Map?) ?? {};
    final flow = (s['flow'] as String?) ?? '';

    final out = <String, dynamic>{
      'type': 'vless',
      'tag': tag,
      'server': host,
      'server_port': port,
      'uuid': ps['uuid'] ?? '',
      if (flow.isNotEmpty) 'flow': flow,
      'packet_encoding': 'xudp',
    };

    // TLS — VLESS 协议规范强制要求 TLS,即使 server.tls 字段未设也要给基础 TLS 段
    out['tls'] = _buildTls(s, tls) ?? <String, dynamic>{
      'enabled': true,
      'server_name': (tls['server_name'] as String?) ??
          (tls['sni'] as String?) ??
          host,
    };

    // 传输层
    final transport = _buildTransport(network, ns);
    if (transport != null) out['transport'] = transport;

    return out;
  }

  // ─── Trojan ──────────────────────────────────────────────────────
  static Map<String, dynamic> _buildTrojan(
      Map<String, dynamic> s, String tag, String host, int port) {
    final ps = (s['protocol_settings'] as Map?) ?? {};
    final tls = (s['tls_settings'] as Map?) ?? {};
    final network = (s['network'] as String?) ?? 'tcp';
    final ns = (s['network_settings'] as Map?) ?? {};

    final out = <String, dynamic>{
      'type': 'trojan',
      'tag': tag,
      'server': host,
      'server_port': port,
      'password': ps['password'] ?? '',
    };

    // Trojan 协议规范同样必须 TLS
    out['tls'] = _buildTls(s, tls) ?? <String, dynamic>{
      'enabled': true,
      'server_name': (tls['server_name'] as String?) ??
          (tls['sni'] as String?) ??
          host,
    };

    final transport = _buildTransport(network, ns);
    if (transport != null) out['transport'] = transport;

    return out;
  }

  // ─── AnyTLS ──────────────────────────────────────────────────────
  static Map<String, dynamic> _buildAnyTls(
      Map<String, dynamic> s, String tag, String host, int port) {
    final ps = (s['protocol_settings'] as Map?) ?? {};
    final tls = (s['tls_settings'] as Map?) ?? {};

    final out = <String, dynamic>{
      'type': 'anytls',
      'tag': tag,
      'server': host,
      'server_port': port,
      'password': ps['password'] ?? '',
      'idle_session_check_interval': '30s',
      'idle_session_timeout': '30s',
    };

    // AnyTLS 必须 TLS
    out['tls'] = _buildTls(s, tls) ?? <String, dynamic>{
      'enabled': true,
      'server_name': (tls['server_name'] as String?) ??
          (tls['sni'] as String?) ??
          host,
    };

    return out;
  }

  // ─── Shadowsocks ─────────────────────────────────────────────────
  static Map<String, dynamic> _buildShadowsocks(
      Map<String, dynamic> s, String tag, String host, int port) {
    final ps = (s['protocol_settings'] as Map?) ?? {};
    final cipher = (s['cipher'] as String?) ?? 'aes-128-gcm';
    return {
      'type': 'shadowsocks',
      'tag': tag,
      'server': host,
      'server_port': port,
      'method': cipher,
      'password': ps['password'] ?? '',
    };
  }

  // ─── VMess ───────────────────────────────────────────────────────
  static Map<String, dynamic> _buildVmess(
      Map<String, dynamic> s, String tag, String host, int port) {
    final ps = (s['protocol_settings'] as Map?) ?? {};
    final tls = (s['tls_settings'] as Map?) ?? {};
    final network = (s['network'] as String?) ?? 'tcp';
    final ns = (s['network_settings'] as Map?) ?? {};

    final out = <String, dynamic>{
      'type': 'vmess',
      'tag': tag,
      'server': host,
      'server_port': port,
      'uuid': ps['uuid'] ?? '',
      'security': 'auto',
      'alter_id': 0,
    };

    final tlsCfg = _buildTls(s, tls);
    if (tlsCfg != null) out['tls'] = tlsCfg;

    final transport = _buildTransport(network, ns);
    if (transport != null) out['transport'] = transport;

    return out;
  }

  // ─── Hysteria2 ───────────────────────────────────────────────────
  static Map<String, dynamic> _buildHysteria2(
      Map<String, dynamic> s, String tag, String host, int port) {
    final ps = (s['protocol_settings'] as Map?) ?? {};
    final tls = (s['tls_settings'] as Map?) ?? {};
    return {
      'type': 'hysteria2',
      'tag': tag,
      'server': host,
      'server_port': port,
      'password': ps['password'] ?? '',
      'tls': _buildTls(s, tls) ?? {'enabled': true, 'server_name': host},
    };
  }

  // ─── TLS 配置(VLESS Reality / Trojan TLS / 标准 TLS 都走这里) ─────
  static Map<String, dynamic>? _buildTls(
      Map<String, dynamic> s, Map tlsSettings) {
    // 后端返回的 tls 字段可能是 String("0"/"1"/"2") / int / bool 任一种,
    // mihomo_config_generator 用 == 比较多种类型,这里照搬以兼容。
    final tlsField = s['tls'];
    // 检测 reality:tls=2 或 tls_settings 里有 public_key(后端有时不设 tls=2 但 tlsSettings 已有 reality 字段)
    final hasRealityKey = ((tlsSettings['public_key'] as String?)?.isNotEmpty ?? false) ||
        ((tlsSettings['reality_public_key'] as String?)?.isNotEmpty ?? false);
    final tlsEnabled = tlsField == 1 ||
        tlsField == '1' ||
        tlsField == 2 ||
        tlsField == '2' ||
        tlsField == true ||
        hasRealityKey ||  // tls_settings 里有 reality public_key → 强制启 TLS
        ((tlsSettings['server_name'] as String?)?.isNotEmpty ?? false);  // 或 SNI 非空也启
    if (!tlsEnabled) return null;

    final out = <String, dynamic>{
      'enabled': true,
    };
    final sni = (tlsSettings['server_name'] as String?) ??
        (tlsSettings['sni'] as String?) ??
        '';
    if (sni.isNotEmpty) out['server_name'] = sni;
    final allowInsecure = (tlsSettings['allow_insecure'] as bool?) ?? false;
    if (allowInsecure) out['insecure'] = true;
    final alpn = tlsSettings['alpn'];
    if (alpn is List && alpn.isNotEmpty) {
      out['alpn'] = alpn.map((e) => e.toString()).toList();
    } else if (alpn is String && alpn.isNotEmpty) {
      out['alpn'] = alpn.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    final fp = (tlsSettings['fingerprint'] as String?) ?? '';
    if (fp.isNotEmpty) out['utls'] = {'enabled': true, 'fingerprint': fp};

    // Reality
    final realityPbk = (tlsSettings['reality_public_key'] as String?) ??
        (tlsSettings['public_key'] as String?) ??
        '';
    if (realityPbk.isNotEmpty) {
      final shortId = (tlsSettings['reality_short_id'] as String?) ??
          (tlsSettings['short_id'] as String?) ??
          '';
      out['reality'] = {
        'enabled': true,
        'public_key': realityPbk,
        'short_id': shortId,
      };
      // Reality 强制需要 uTLS 指纹伪装(否则 sing-box 报 "uTLS is required by reality client"),
      // 如果上面 fingerprint 字段没设,默认 chrome(V2Board 后端 fingerprint 默认值)
      out['utls'] ??= <String, dynamic>{'enabled': true, 'fingerprint': 'chrome'};
    }

    return out;
  }

  // ─── 传输层 transport(ws/grpc/h2/httpupgrade) ────────────────────
  static Map<String, dynamic>? _buildTransport(String network, Map ns) {
    switch (network.toLowerCase()) {
      case 'ws':
      case 'websocket':
        return {
          'type': 'ws',
          'path': (ns['path'] as String?) ?? '/',
          'headers': (ns['headers'] is Map)
              ? Map<String, dynamic>.from(ns['headers'] as Map)
              : <String, dynamic>{},
        };
      case 'grpc':
        return {
          'type': 'grpc',
          'service_name': (ns['serviceName'] as String?) ??
              (ns['service_name'] as String?) ??
              '',
        };
      case 'h2':
      case 'http':
        return {
          'type': 'http',
          'path': (ns['path'] as String?) ?? '/',
          'host': (ns['host'] is List)
              ? List<String>.from(ns['host'] as List)
              : (ns['host'] is String && (ns['host'] as String).isNotEmpty)
                  ? [ns['host'] as String]
                  : <String>[],
        };
      case 'httpupgrade':
        return {
          'type': 'httpupgrade',
          'path': (ns['path'] as String?) ?? '/',
          'host': (ns['host'] as String?) ?? '',
        };
      case 'tcp':
      case 'raw':
      default:
        return null; // TCP raw 不需要 transport 字段
    }
  }
}
