import 'dart:convert';

/// 代理协议类型
enum ProxyProtocol {
  shadowsocks,
  vmess,
  vless,
  trojan,
  hysteria,
  hysteria2,
  unknown,
}

/// 代理配置模型
class ProxyConfig {
  final ProxyProtocol protocol;
  final String name;
  final String address;
  final int port;
  final String? password;
  final String? uuid;
  final String? method; // 加密方式
  final String? network; // ws, tcp, grpc, etc.
  final String? path; // WebSocket path
  final String? host; // WebSocket host
  final String? sni; // TLS SNI
  final bool tls;
  final String? flow; // VLESS flow
  final String? fingerprint;
  final String? publicKey; // Hysteria2
  final Map<String, dynamic>? extra;

  ProxyConfig({
    required this.protocol,
    required this.name,
    required this.address,
    required this.port,
    this.password,
    this.uuid,
    this.method,
    this.network,
    this.path,
    this.host,
    this.sni,
    this.tls = false,
    this.flow,
    this.fingerprint,
    this.publicKey,
    this.extra,
  });

  Map<String, dynamic> toJson() => {
        'protocol': protocol.name,
        'name': name,
        'address': address,
        'port': port,
        'password': password,
        'uuid': uuid,
        'method': method,
        'network': network,
        'path': path,
        'host': host,
        'sni': sni,
        'tls': tls,
        'flow': flow,
        'fingerprint': fingerprint,
        'publicKey': publicKey,
        'extra': extra,
      };
}

/// 协议解析器
class ProtocolParser {
  ProtocolParser._();

  /// 解析订阅内容
  static List<ProxyConfig> parseSubscription(String content) {
    final configs = <ProxyConfig>[];

    // 尝试 Base64 解码
    String decoded;
    try {
      decoded = utf8.decode(base64Decode(content.trim()));
    } catch (_) {
      decoded = content;
    }

    // 按行解析
    final lines = decoded.split('\n').where((l) => l.trim().isNotEmpty);

    for (final line in lines) {
      final config = parseLine(line.trim());
      if (config != null) {
        configs.add(config);
      }
    }

    return configs;
  }

  /// 解析单行配置
  static ProxyConfig? parseLine(String line) {
    try {
      if (line.startsWith('ss://')) {
        return _parseShadowsocks(line);
      } else if (line.startsWith('vmess://')) {
        return _parseVmess(line);
      } else if (line.startsWith('vless://')) {
        return _parseVless(line);
      } else if (line.startsWith('trojan://')) {
        return _parseTrojan(line);
      } else if (line.startsWith('hysteria://')) {
        return _parseHysteria(line);
      } else if (line.startsWith('hysteria2://') || line.startsWith('hy2://')) {
        return _parseHysteria2(line);
      }
    } catch (e) {
      // 解析失败，忽略该行
    }
    return null;
  }

  /// 解析 Shadowsocks 链接
  static ProxyConfig? _parseShadowsocks(String link) {
    // ss://BASE64(method:password)@host:port#name
    // 或 ss://BASE64(method:password@host:port)#name

    final uri = Uri.parse(link);
    String? name = uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : null;

    String? method;
    String? password;
    String? host;
    int? port;

    if (uri.userInfo.isNotEmpty) {
      // 新格式: ss://BASE64@host:port
      final decoded = utf8.decode(base64Decode(_addBase64Padding(uri.userInfo)));
      final parts = decoded.split(':');
      if (parts.length >= 2) {
        method = parts[0];
        password = parts.sublist(1).join(':');
      }
      host = uri.host;
      port = uri.port;
    } else {
      // 旧格式: ss://BASE64#name
      final base64Part = link.substring(5).split('#')[0];
      final decoded = utf8.decode(base64Decode(_addBase64Padding(base64Part)));

      // method:password@host:port
      final atIndex = decoded.lastIndexOf('@');
      if (atIndex > 0) {
        final userInfo = decoded.substring(0, atIndex);
        final hostPort = decoded.substring(atIndex + 1);

        final userParts = userInfo.split(':');
        method = userParts[0];
        password = userParts.sublist(1).join(':');

        final hostParts = hostPort.split(':');
        host = hostParts[0];
        port = int.tryParse(hostParts[1]);
      }
    }

    if (host == null || port == null) return null;

    return ProxyConfig(
      protocol: ProxyProtocol.shadowsocks,
      name: name ?? '$host:$port',
      address: host,
      port: port,
      method: method,
      password: password,
    );
  }

  /// 解析 VMess 链接
  static ProxyConfig? _parseVmess(String link) {
    // vmess://BASE64(JSON)
    final base64Part = link.substring(8);
    final jsonStr = utf8.decode(base64Decode(_addBase64Padding(base64Part)));
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;

    return ProxyConfig(
      protocol: ProxyProtocol.vmess,
      name: json['ps']?.toString() ?? json['add']?.toString() ?? 'VMess',
      address: json['add']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '0') ?? 0,
      uuid: json['id']?.toString(),
      method: json['scy']?.toString() ?? 'auto',
      network: json['net']?.toString(),
      path: json['path']?.toString(),
      host: json['host']?.toString(),
      sni: json['sni']?.toString(),
      tls: json['tls']?.toString() == 'tls',
      extra: {
        'aid': json['aid'],
        'type': json['type'],
        'alpn': json['alpn'],
      },
    );
  }

  /// 解析 VLESS 链接
  static ProxyConfig? _parseVless(String link) {
    // vless://uuid@host:port?params#name
    final uri = Uri.parse(link);
    final params = uri.queryParameters;

    return ProxyConfig(
      protocol: ProxyProtocol.vless,
      name: uri.fragment.isNotEmpty
          ? Uri.decodeComponent(uri.fragment)
          : '${uri.host}:${uri.port}',
      address: uri.host,
      port: uri.port,
      uuid: uri.userInfo,
      network: params['type'] ?? 'tcp',
      path: params['path'],
      host: params['host'],
      sni: params['sni'],
      tls: params['security'] == 'tls' || params['security'] == 'xtls',
      flow: params['flow'],
      fingerprint: params['fp'],
      extra: {
        'encryption': params['encryption'],
        'alpn': params['alpn'],
        'pbk': params['pbk'],
        'sid': params['sid'],
      },
    );
  }

  /// 解析 Trojan 链接
  static ProxyConfig? _parseTrojan(String link) {
    // trojan://password@host:port?params#name
    final uri = Uri.parse(link);
    final params = uri.queryParameters;

    return ProxyConfig(
      protocol: ProxyProtocol.trojan,
      name: uri.fragment.isNotEmpty
          ? Uri.decodeComponent(uri.fragment)
          : '${uri.host}:${uri.port}',
      address: uri.host,
      port: uri.port,
      password: Uri.decodeComponent(uri.userInfo),
      network: params['type'] ?? 'tcp',
      path: params['path'],
      host: params['host'],
      sni: params['sni'] ?? uri.host,
      tls: true, // Trojan 默认 TLS
      fingerprint: params['fp'],
      extra: {
        'alpn': params['alpn'],
      },
    );
  }

  /// 解析 Hysteria 链接
  static ProxyConfig? _parseHysteria(String link) {
    // hysteria://host:port?params#name
    final uri = Uri.parse(link);
    final params = uri.queryParameters;

    return ProxyConfig(
      protocol: ProxyProtocol.hysteria,
      name: uri.fragment.isNotEmpty
          ? Uri.decodeComponent(uri.fragment)
          : '${uri.host}:${uri.port}',
      address: uri.host,
      port: uri.port,
      password: params['auth'],
      sni: params['peer'] ?? params['sni'],
      tls: true,
      extra: {
        'protocol': params['protocol'],
        'upmbps': params['upmbps'],
        'downmbps': params['downmbps'],
        'alpn': params['alpn'],
        'obfs': params['obfs'],
        'obfsParam': params['obfsParam'],
      },
    );
  }

  /// 解析 Hysteria2 链接
  static ProxyConfig? _parseHysteria2(String link) {
    // hysteria2://auth@host:port?params#name
    // hy2://auth@host:port?params#name
    final uri = Uri.parse(link);
    final params = uri.queryParameters;

    return ProxyConfig(
      protocol: ProxyProtocol.hysteria2,
      name: uri.fragment.isNotEmpty
          ? Uri.decodeComponent(uri.fragment)
          : '${uri.host}:${uri.port}',
      address: uri.host,
      port: uri.port,
      password: Uri.decodeComponent(uri.userInfo),
      sni: params['sni'] ?? uri.host,
      tls: true,
      extra: {
        'obfs': params['obfs'],
        'obfs-password': params['obfs-password'],
        'insecure': params['insecure'],
      },
    );
  }

  /// 添加 Base64 填充
  static String _addBase64Padding(String str) {
    final padding = (4 - str.length % 4) % 4;
    return str + '=' * padding;
  }
}
