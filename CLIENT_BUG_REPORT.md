# 客户端 vs 后端规范：完整对照 Bug 报告
> 基于 V2BOARD_BACKEND_SPEC.md 深度对照分析
> 生成时间：2026-04-10

---

## 总览

| 严重程度 | 数量 | 说明 |
|---------|------|------|
| 🔴 CRITICAL | 4 | 直接导致崩溃或功能完全失效 |
| 🟠 HIGH | 6 | 功能缺失，部分用户无法连接 |
| 🟡 MEDIUM | 3 | 行为不符合规范，可能影响稳定性 |
| ✅ 已修复 | 8 | 本次会话中已完成修复 |

---

## ✅ 已修复（8项）

| # | 问题 | 修复位置 |
|---|------|---------|
| 1 | 端口优先级反转（server_port 优先于 port） | `config_generator.dart:332` |
| 2 | tls='2' 不识别为 TLS 启用（Reality 失效） | `config_generator.dart:340` |
| 3 | VLess Reality 配置未生成 | `singbox_config.dart` + `outbound_builder.dart` + `config_generator.dart` |
| 4 | Hysteria v1/v2 不区分（均当 v1 处理） | `vpn_bloc.dart _serverToConfigMap()` |
| 5 | Hysteria v1 带宽 up_mbps/down_mbps 未传递 | `vpn_bloc.dart` |
| 6 | Trojan TLS 字段（server_name/allow_insecure）丢失 | `vpn_bloc.dart` |
| 7 | Hysteria TLS 字段（server_name/insecure）丢失 | `vpn_bloc.dart` |
| 8 | node_unreachable 错误静默吞掉 | `home_page.dart` |

---

## 🔴 CRITICAL（4项）—— 直接崩溃或完全失效

---

### C-1：端口范围字符串导致类型转换崩溃

**影响协议：** Hysteria（多端口节点）、所有配置了端口范围的协议  
**文件：** `packages/singbox_flutter/lib/src/config_generator/config_generator.dart:332`

**问题：**
后端 `port` 字段可能是范围字符串 `"8000-9000"`（存在 `mport` 字段时），但代码强制 `as int?` 转换：
```dart
// 当前（❌）：
final port = server['port'] as int? ?? server['server_port'] as int? ?? 443;
// "8000-9000" as int? → 不是 int，得到 null → 使用 server_port（后端监听端口，错误）
```

**修复方案：**
```dart
// 正确：
final port = _parsePort(server['port']) ?? _parsePort(server['server_port']) ?? 443;

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
```

同时 `ServerModel` 需要增加 `mport` 字段：
```dart
// server_model.dart 增加：
@JsonKey(name: 'mport')
final String? mport;
```

---

### C-2：TUIC 协议完全未实现

**影响：** 所有 TUIC 节点用户点击连接直接崩溃  
**文件：** `config_generator.dart`（无 `tuic` case）、`outbound_builder.dart`（无 `buildTuic`）、`singbox_config.dart`（无 `TuicOutboundConfig`）

**后端返回字段：**
```json
{
  "type": "tuic",
  "server_name": "sni.example.com",
  "insecure": 0,
  "disable_sni": 0,
  "congestion_control": "cubic",
  "udp_relay_mode": "native",
  "zero_rtt_handshake": 0
}
```

**需要新增：**

1. `singbox_config.dart` → 新增 `TuicOutboundConfig` 类
2. `outbound_builder.dart` → 新增 `buildTuic()` 方法
3. `config_generator.dart` → 新增 `case 'tuic'`
4. `vpn_bloc.dart _serverToConfigMap()` → TUIC 用 uuid + password，均为 `user.uuid`；需传递 `congestion_control`、`udp_relay_mode`、`zero_rtt_handshake`、`disable_sni`

**sing-box 输出格式：**
```json
{
  "type": "tuic",
  "tag": "proxy",
  "server": "host",
  "server_port": 443,
  "uuid": "user-uuid",
  "password": "user-uuid",
  "congestion_control": "cubic",
  "udp_relay_mode": "native",
  "zero_rtt_handshake": false,
  "tls": {
    "enabled": true,
    "server_name": "sni",
    "insecure": false,
    "alpn": ["h3"],
    "disable_sni": false
  }
}
```

---

### C-3：AnyTLS 协议完全未实现

**影响：** 所有 AnyTLS 节点用户点击连接直接崩溃  
**文件：** 同 TUIC，三个文件均无 `anytls` 支持

**后端返回字段：**
```json
{
  "type": "anytls",
  "server_name": "sni.example.com",
  "insecure": 0,
  "padding_scheme": null
}
```

**sing-box 输出格式：**
```json
{
  "type": "anytls",
  "tag": "proxy",
  "server": "host",
  "server_port": 443,
  "password": "user-uuid",
  "tls": {
    "enabled": true,
    "server_name": "sni",
    "insecure": false,
    "alpn": ["h2", "http/1.1"]
  }
}
```

---

### C-4：Hysteria v1/v2 obfs 字段完全错误

**影响：** 所有配置了 obfs 混淆的 Hysteria 节点无法连接  
**文件：** `vpn_bloc.dart:407`、`config_generator.dart:441,453`

**规范定义（后端返回字段位置）：**

| 版本 | 字段位置 | 字段名 | 含义 |
|------|---------|--------|------|
| v1 | **顶层** `server.obfs` | 字符串 | obfs 密码（直接是密码，不是类型） |
| v2 | **顶层** `server.obfs` | 字符串 | obfs 类型（如 `salamander`） |
| v2 | **顶层** `server.obfsPassword` | 字符串 | obfs 密码 |

**当前代码（❌ 错误）：**
```dart
// vpn_bloc.dart：
'obfs_settings': server.obfsSettings ?? {},  // obfsSettings 是 JSON 列的解析，但 Hysteria 的 obfs 在顶层字段里！

// config_generator.dart v1：
obfs: obfsSettings['type'] as String?,  // 错误！v1 的 obfs 是密码字符串，不是类型
```

**修复方案：**
```dart
// vpn_bloc.dart _serverToConfigMap()，Hysteria 部分增加：
if (effectiveType == 'hysteria') {
  // v1：obfs 字段本身就是混淆密码
  if (server.obfs != null) {
    obfsSettings['password'] = server.obfs;
  }
}
if (effectiveType == 'hysteria2') {
  // v2：obfs 是类型，obfsPassword 是密码
  if (server.obfs != null) {
    obfsSettings['type'] = server.obfs;
    obfsSettings['password'] = server.obfsPassword ?? '';
  }
}

// config_generator.dart v1：
obfs: obfsSettings['password'] as String?,  // v1 直接取密码
```

---

## 🟠 HIGH（6项）—— 功能缺失

---

### H-1：Shadowsocks obfs plugin 格式转换缺失

**文件：** `config_generator.dart:370-378`

**问题：**
- 后端返回：`obfs_settings = {host: "...", path: "/"}` 或顶层 `obfs-host`/`obfs-path`
- 代码期望：`obfsSettings['plugin']` 和 `obfsSettings['plugin_opts']`（直接的 sing-box 格式）
- 两者完全不匹配 → obfs 静默失效，混淆不生效

**修复：**
```dart
// config_generator.dart，shadowsocks case：
String? plugin;
String? pluginOpts;
if (obfsSettings.isNotEmpty || server['obfs'] == 'http') {
  final obfsHost = obfsSettings['host'] as String? ??
                   server['obfs-host'] as String? ?? '';
  final obfsPath = obfsSettings['path'] as String? ??
                   server['obfs-path'] as String? ?? '/';
  plugin = 'obfs-local';
  pluginOpts = 'obfs=http;obfs-host=$obfsHost;obfs-path=$obfsPath';
}
```

---

### H-2：VLess 缺失 packet_encoding

**文件：** `config_generator.dart:394-418`、`singbox_config.dart`、`outbound_builder.dart`

**规范要求：** VLess sing-box 输出需包含 `"packet_encoding": "xudp"`

**修复：**
```dart
// singbox_config.dart VLessOutboundConfig.toJson() 增加：
json['packet_encoding'] = 'xudp';
```

---

### H-3：VMess WebSocket 缺失 early_data 参数

**文件：** `singbox_config.dart WsTransportConfig`、`outbound_builder.dart buildVMess()`

**规范要求：**
```json
"transport": {
  "type": "ws",
  "path": "/path",
  "max_early_data": 2048,
  "early_data_header_name": "Sec-WebSocket-Protocol"
}
```

**修复：** `WsTransportConfig` 增加 `maxEarlyData`、`earlyDataHeaderName` 字段

---

### H-4：TUIC disable_sni 未传递

**文件：** `vpn_bloc.dart`、`singbox_config.dart TlsConfig`

**问题：** `TlsConfig` 无 `disable_sni` 字段，TUIC 的 `disableSni` 无法传递到 sing-box

**修复：** `TlsConfig` 增加 `final bool disableSni`，`toJson()` 中输出 `"disable_sni": true`

---

### H-5：ServerModel 缺失 mport 字段

**文件：** `lib/data/models/server_model.dart`

**问题：** 后端返回 `mport`（端口范围原始字符串），但 `ServerModel` 无对应字段，无法正确处理多端口

**修复：**
```dart
@JsonKey(name: 'mport')
final String? mport;
```

---

### H-6：AnyTLS padding_scheme 未实现

**文件：** `server_model.dart`、整个协议链路

**问题：** `padding_scheme` 字段规范中存在，模型和配置生成器均未实现

---

## 🟡 MEDIUM（3项）—— 行为偏差

---

### M-1：VMess tlsSettings 字段提取需双重验证

**文件：** `config_generator.dart:346-348`

**当前代码已做兼容：**
```dart
final serverName = tlsSettings['server_name'] as String? ??
    tlsSettings['serverName'] as String? ??
    host;
```
但 `allowInsecure`（驼峰）未做同样兼容，只检查 `allow_insecure`（下划线）

**修复：**
```dart
final insecure = tlsSettings['allow_insecure'] == true ||
    tlsSettings['allowInsecure'] == true ||  // ← 已有
    tlsSettings['allow_insecure'] == 1 ||    // ← 增加数字兼容
    tlsSettings['allowInsecure'] == 1;
```

---

### M-2：VLess flow 字段在无 TLS 时不应传递

**文件：** `config_generator.dart:394-418`

**规范：** `flow` 仅在 `TCP + TLS/Reality` 时有效，其他 transport 下应忽略

---

### M-3：Hysteria 端口范围时 mport 未用于随机选取

**文件：** `vpn_bloc.dart _serverToConfigMap()`

**问题：** 当 `server.mport` 存在时，应从范围内随机选取端口，当前直接透传 `server.port`

---

## 修复优先级路线图

```
第一阶段（立即，影响所有用户）：
  C-1  端口范围字符串崩溃
  C-4  Hysteria obfs 字段错误
  H-1  SS obfs plugin 格式转换

第二阶段（本周，补全协议支持）：
  C-2  实现 TUIC 协议
  C-3  实现 AnyTLS 协议
  H-2  VLess packet_encoding
  H-4  TUIC disable_sni

第三阶段（下周，完整性）：
  H-3  VMess early_data
  H-5  mport 字段
  H-6  AnyTLS padding_scheme
  M-1  VMess allowInsecure 数字兼容
  M-2  flow 字段过滤
  M-3  mport 随机端口
```

---

## 涉及文件汇总

| 文件 | 需要修改 |
|------|---------|
| `lib/data/models/server_model.dart` | 增加 `mport` 字段 |
| `lib/presentation/blocs/vpn/vpn_bloc.dart` | Hysteria obfs 处理、TUIC/AnyTLS 支持 |
| `packages/singbox_flutter/lib/src/singbox_config.dart` | 新增 `TuicOutboundConfig`、`AnyTLSOutboundConfig`；`TlsConfig` 增加 `disable_sni`；`VLessOutboundConfig` 增加 `packet_encoding`；`WsTransportConfig` 增加 `early_data` |
| `packages/singbox_flutter/lib/src/config_generator/outbound_builder.dart` | 新增 `buildTuic()`、`buildAnyTLS()` |
| `packages/singbox_flutter/lib/src/config_generator/config_generator.dart` | 端口解析修复；新增 `tuic`/`anytls` case；SS obfs 转换；VLess packet_encoding |
