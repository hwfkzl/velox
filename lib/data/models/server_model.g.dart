// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerModel _$ServerModelFromJson(Map<String, dynamic> json) => ServerModel(
  id: (json['id'] as num?)?.toInt(),
  groupId: ServerModel._parseGroupId(json['group_id']),
  name: json['name'] as String?,
  parentId: (json['parent_id'] as num?)?.toInt(),
  host: json['host'] as String?,
  port: (json['port'] as num?)?.toInt(),
  mport: json['mport'] as String?,
  serverPort: (json['server_port'] as num?)?.toInt(),
  cipher: json['cipher'] as String?,
  rate: ServerModel._parseRate(json['rate']),
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  network: json['network'] as String?,
  networkSettings: json['network_settings'] as Map<String, dynamic>?,
  tls: ServerModel._parseTls(json['tls']),
  tlsSettings: json['tls_settings'] as Map<String, dynamic>?,
  flow: json['flow'] as String?,
  protocol: json['protocol'] as String?,
  protocolSettings: json['protocol_settings'] as Map<String, dynamic>?,
  obfsSettings: json['obfs_settings'] as Map<String, dynamic>?,
  createdAt: (json['created_at'] as num?)?.toInt(),
  updatedAt: (json['updated_at'] as num?)?.toInt(),
  sort: (json['sort'] as num?)?.toInt(),
  show: (json['show'] as num?)?.toInt(),
  type: json['type'] as String?,
  serverName: json['server_name'] as String?,
  allowInsecure: ServerModel._parseBool(json['allow_insecure']),
  insecure: ServerModel._parseBool(json['insecure']),
  version: (json['version'] as num?)?.toInt(),
  upMbps: (json['up_mbps'] as num?)?.toInt(),
  downMbps: (json['down_mbps'] as num?)?.toInt(),
  obfs: json['obfs'] as String?,
  obfsPassword: json['obfs_password'] as String?,
  congestionControl: json['congestion_control'] as String?,
  udpRelayMode: json['udp_relay_mode'] as String?,
  backendOnline: (json['is_online'] as num?)?.toInt(),
  zeroRttHandshake: ServerModel._parseBool(json['zero_rtt_handshake']),
  disableSni: ServerModel._parseBool(json['disable_sni']),
  paddingScheme: ServerModel._parsePaddingScheme(json['padding_scheme']),
  encryption: json['encryption'] as String?,
  encryptionSettings: json['encryption_settings'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ServerModelToJson(ServerModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'group_id': instance.groupId,
      'name': instance.name,
      'parent_id': instance.parentId,
      'host': instance.host,
      'port': instance.port,
      'mport': instance.mport,
      'server_port': instance.serverPort,
      'cipher': instance.cipher,
      'rate': instance.rate,
      'tags': instance.tags,
      'network': instance.network,
      'network_settings': instance.networkSettings,
      'tls': instance.tls,
      'tls_settings': instance.tlsSettings,
      'flow': instance.flow,
      'protocol': instance.protocol,
      'protocol_settings': instance.protocolSettings,
      'obfs_settings': instance.obfsSettings,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'sort': instance.sort,
      'show': instance.show,
      'type': instance.type,
      'server_name': instance.serverName,
      'allow_insecure': instance.allowInsecure,
      'insecure': instance.insecure,
      'version': instance.version,
      'up_mbps': instance.upMbps,
      'down_mbps': instance.downMbps,
      'obfs': instance.obfs,
      'obfs_password': instance.obfsPassword,
      'congestion_control': instance.congestionControl,
      'udp_relay_mode': instance.udpRelayMode,
      'zero_rtt_handshake': instance.zeroRttHandshake,
      'disable_sni': instance.disableSni,
      'padding_scheme': instance.paddingScheme,
      'encryption': instance.encryption,
      'encryption_settings': instance.encryptionSettings,
      'is_online': instance.backendOnline,
    };

ServerGroupModel _$ServerGroupModelFromJson(Map<String, dynamic> json) =>
    ServerGroupModel(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      createdAt: (json['created_at'] as num?)?.toInt(),
      updatedAt: (json['updated_at'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ServerGroupModelToJson(ServerGroupModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
