import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'server_model.g.dart';

@JsonSerializable()
class ServerModel {
  final int? id;
  @JsonKey(name: 'group_id', fromJson: _parseGroupId)
  final List<String>? groupId;

  static List<String>? _parseGroupId(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  // V2Board 返回 tls 为整数 0/1，兼容转换为字符串
  static String? _parseTls(dynamic value) => value?.toString();

  // V2Board 返回 rate 为数字，兼容转换为字符串
  static String? _parseRate(dynamic value) => value?.toString();

  // tinyint(1) → bool
  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value != 0;
    return null;
  }

  // padding_scheme：后端用户订阅端点 (getAvailableAnyTLS) 经模型 array cast
  // 直接下发 JSON 数组，而 admin 端点 (getAllAnyTLS) 又会 json_encode 成字符串。
  // 两种格式都要兼容，否则数组形态会在反序列化时抛 CastError 拖垮整个节点列表。
  static String? _parsePaddingScheme(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return jsonEncode(value);
  }

  final String? name;
  @JsonKey(name: 'parent_id')
  final int? parentId;
  final String? host;
  final int? port;
  /// 多端口范围字符串，如 "8000-9000"，优先于 port 使用
  final String? mport;
  @JsonKey(name: 'server_port')
  final int? serverPort;
  final String? cipher;
  @JsonKey(fromJson: _parseRate)
  final String? rate;
  final List<String>? tags;
  final String? network;
  @JsonKey(name: 'network_settings')
  final Map<String, dynamic>? networkSettings;
  @JsonKey(fromJson: _parseTls)
  final String? tls;
  @JsonKey(name: 'tls_settings')
  final Map<String, dynamic>? tlsSettings;
  final String? flow;
  final String? protocol;
  @JsonKey(name: 'protocol_settings')
  final Map<String, dynamic>? protocolSettings;
  @JsonKey(name: 'obfs_settings')
  final Map<String, dynamic>? obfsSettings;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @JsonKey(name: 'updated_at')
  final int? updatedAt;
  final int? sort;
  final int? show;
  final String? type;

  // ── Trojan / Hysteria / Tuic / AnyTLS 共用 ──
  @JsonKey(name: 'server_name')
  final String? serverName;

  // Trojan 专用（DB 列名 allow_insecure）
  @JsonKey(name: 'allow_insecure', fromJson: _parseBool)
  final bool? allowInsecure;

  // Hysteria / Tuic / AnyTLS 专用（DB 列名 insecure）
  @JsonKey(fromJson: _parseBool)
  final bool? insecure;

  // Hysteria v1/v2 版本区分
  final int? version;

  // Hysteria v1 带宽
  @JsonKey(name: 'up_mbps')
  final int? upMbps;
  @JsonKey(name: 'down_mbps')
  final int? downMbps;

  // Shadowsocks / Hysteria obfs
  final String? obfs;
  @JsonKey(name: 'obfs_password')
  final String? obfsPassword;

  // Tuic 专用
  @JsonKey(name: 'congestion_control')
  final String? congestionControl;
  @JsonKey(name: 'udp_relay_mode')
  final String? udpRelayMode;
  @JsonKey(name: 'zero_rtt_handshake', fromJson: _parseBool)
  final bool? zeroRttHandshake;
  @JsonKey(name: 'disable_sni', fromJson: _parseBool)
  final bool? disableSni;

  // AnyTLS 专用
  @JsonKey(name: 'padding_scheme', fromJson: _parsePaddingScheme)
  final String? paddingScheme;

  // VLESS 后量子加密专用（v2node 引入；对应 mihomo `encryption` 字段）
  // 顶层算法名（如 'mlkem768x25519plus'）
  final String? encryption;
  // 加密细节：{mode, rtt, client_padding?, password}
  @JsonKey(name: 'encryption_settings')
  final Map<String, dynamic>? encryptionSettings;

  // 后端权威状态：5 分钟内服务端有上报心跳 = 1，否则 0
  // CDN 中转架构下，客户端 TCP 握手只能测到 CDN 入口（永远成功），
  // 必须依赖后端这个字段来判断节点是否真的在线
  @JsonKey(name: 'is_online')
  final int? backendOnline;

  // 客户端计算字段
  @JsonKey(includeFromJson: false, includeToJson: false)
  int? latency;
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isFavorite;
  @JsonKey(includeFromJson: false, includeToJson: false)
  double? load;

  ServerModel({
    this.id,
    this.groupId,
    this.name,
    this.parentId,
    this.host,
    this.port,
    this.mport,
    this.serverPort,
    this.cipher,
    this.rate,
    this.tags,
    this.network,
    this.networkSettings,
    this.tls,
    this.tlsSettings,
    this.flow,
    this.protocol,
    this.protocolSettings,
    this.obfsSettings,
    this.createdAt,
    this.updatedAt,
    this.sort,
    this.show,
    this.type,
    this.serverName,
    this.allowInsecure,
    this.insecure,
    this.version,
    this.upMbps,
    this.downMbps,
    this.obfs,
    this.obfsPassword,
    this.congestionControl,
    this.udpRelayMode,
    this.backendOnline,
    this.zeroRttHandshake,
    this.disableSni,
    this.paddingScheme,
    this.encryption,
    this.encryptionSettings,
    this.latency,
    this.isFavorite = false,
    this.load,
  });

  factory ServerModel.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    // VMess 后端返回驼峰式字段名，统一转为下划线式
    if (normalized['network_settings'] == null && normalized['networkSettings'] != null) {
      normalized['network_settings'] = normalized['networkSettings'];
    }
    if (normalized['tls_settings'] == null && normalized['tlsSettings'] != null) {
      normalized['tls_settings'] = normalized['tlsSettings'];
    }
    return _$ServerModelFromJson(normalized);
  }

  Map<String, dynamic> toJson() => _$ServerModelToJson(this);

  /// 获取倍率显示
  String get rateDisplay => '${rate ?? 1}x';

  /// 后端是否标记此节点离线（服务端 5 分钟未上报心跳）
  /// 这是 CDN 中转架构下唯一可靠的"节点真实状态"判断
  bool get isBackendOffline => backendOnline == 0;

  /// 综合判断：后端在线 且 客户端测速通过
  bool get isOnline =>
      !isBackendOffline && latency != null && latency! > 0;

  /// 延迟状态
  String get latencyStatus {
    if (latency == null) return 'unknown';
    if (latency! < 100) return 'good';
    if (latency! < 300) return 'medium';
    return 'bad';
  }

  ServerModel copyWith({
    int? id,
    List<String>? groupId,
    String? name,
    int? parentId,
    String? host,
    int? port,
    String? mport,
    int? serverPort,
    String? cipher,
    String? rate,
    List<String>? tags,
    String? network,
    Map<String, dynamic>? networkSettings,
    String? tls,
    Map<String, dynamic>? tlsSettings,
    String? flow,
    String? protocol,
    Map<String, dynamic>? protocolSettings,
    Map<String, dynamic>? obfsSettings,
    int? createdAt,
    int? updatedAt,
    int? sort,
    int? show,
    String? type,
    String? serverName,
    bool? allowInsecure,
    bool? insecure,
    int? version,
    int? upMbps,
    int? downMbps,
    String? obfs,
    String? obfsPassword,
    String? congestionControl,
    String? udpRelayMode,
    bool? zeroRttHandshake,
    bool? disableSni,
    String? paddingScheme,
    String? encryption,
    Map<String, dynamic>? encryptionSettings,
    int? latency,
    bool? isFavorite,
    double? load,
  }) {
    return ServerModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      host: host ?? this.host,
      port: port ?? this.port,
      mport: mport ?? this.mport,
      serverPort: serverPort ?? this.serverPort,
      cipher: cipher ?? this.cipher,
      rate: rate ?? this.rate,
      tags: tags ?? this.tags,
      network: network ?? this.network,
      networkSettings: networkSettings ?? this.networkSettings,
      tls: tls ?? this.tls,
      tlsSettings: tlsSettings ?? this.tlsSettings,
      flow: flow ?? this.flow,
      protocol: protocol ?? this.protocol,
      protocolSettings: protocolSettings ?? this.protocolSettings,
      obfsSettings: obfsSettings ?? this.obfsSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sort: sort ?? this.sort,
      show: show ?? this.show,
      type: type ?? this.type,
      serverName: serverName ?? this.serverName,
      allowInsecure: allowInsecure ?? this.allowInsecure,
      insecure: insecure ?? this.insecure,
      version: version ?? this.version,
      upMbps: upMbps ?? this.upMbps,
      downMbps: downMbps ?? this.downMbps,
      obfs: obfs ?? this.obfs,
      obfsPassword: obfsPassword ?? this.obfsPassword,
      congestionControl: congestionControl ?? this.congestionControl,
      udpRelayMode: udpRelayMode ?? this.udpRelayMode,
      zeroRttHandshake: zeroRttHandshake ?? this.zeroRttHandshake,
      disableSni: disableSni ?? this.disableSni,
      paddingScheme: paddingScheme ?? this.paddingScheme,
      encryption: encryption ?? this.encryption,
      encryptionSettings: encryptionSettings ?? this.encryptionSettings,
      latency: latency ?? this.latency,
      isFavorite: isFavorite ?? this.isFavorite,
      load: load ?? this.load,
    );
  }
}

@JsonSerializable()
class ServerGroupModel {
  final int? id;
  final String? name;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @JsonKey(name: 'updated_at')
  final int? updatedAt;

  ServerGroupModel({
    this.id,
    this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory ServerGroupModel.fromJson(Map<String, dynamic> json) =>
      _$ServerGroupModelFromJson(json);

  Map<String, dynamic> toJson() => _$ServerGroupModelToJson(this);
}
