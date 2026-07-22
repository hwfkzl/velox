# V2Board 后端节点协议规范
> 基于 `/Users/admin/Downloads/test/rear后` (xiaoV2b 版本) 深度分析
> 用于 Flutter 客户端 (Velox/Velox) 对接参考

---

## 目录
1. [API 端点](#1-api-端点)
2. [通用字段](#2-通用字段所有协议)
3. [Shadowsocks](#3-shadowsocks)
4. [VMess](#4-vmess)
5. [VLess](#5-vless-含-reality)
6. [Trojan](#6-trojan)
7. [Hysteria v1 / v2](#7-hysteria-v1--v2)
8. [TUIC](#8-tuic)
9. [AnyTLS](#9-anytls)
10. [用户认证与密钥规则](#10-用户认证与密钥规则)
11. [特殊处理逻辑](#11-特殊处理逻辑)
12. [数据库表字段映射](#12-数据库表字段映射)
13. [ServerService 合并逻辑](#13-serverservice-合并逻辑)
14. [Singbox 配置生成对照](#14-singbox-配置生成对照)
15. [客户端已知 Bug 清单](#15-客户端已知-bug-清单)

---

## 1. API 端点

### 用户节点列表（JWT 认证）
```
GET /api/v1/user/server/fetch
Header: Authorization: Bearer {jwt_token}
        User-Agent: velox/1.0  ← 触发域名替换
```

**响应：**
```json
{
  "data": [ ...servers ]
}
```
- ETag：`sha1(json_encode(cache_keys))`，支持 304 Not Modified
- 自研客户端 UA 含 `velox/` 时，`host` 字段中 `vazxnet.fun` → `vmzxnsj.space`

### 订阅接口（Token 认证）
```
GET /api/v1/client/subscribe?token={user_token}&flag=sing-box
```

---

## 2. 通用字段（所有协议）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | int | 节点 ID |
| `type` | string | 协议类型：`shadowsocks` `vmess` `vless` `trojan` `hysteria` `tuic` `anytls` |
| `name` | string | 节点名称 |
| `host` | string | 连接地址（已做域名替换） |
| `port` | int \| string | 客户端连接端口，**可能是范围字符串** `"8000-9000"` |
| `server_port` | int | 后端实际监听端口 |
| `mport` | string | 多端口原始字符串（仅当 port 包含范围时存在） |
| `rate` | string | 流量倍率 |
| `show` | int | 1=显示 |
| `sort` | int | 排序权重 |
| `group_id` | array | 权限组 ID 数组 |
| `tags` | array | 标签数组 |
| `parent_id` | int\|null | 中继父节点 ID |
| `is_online` | int | 1=在线（300秒内有检查记录） |
| `cache_key` | string | `"{type}-{id}-{updated_at}-{is_online}"` |
| `created_at` | int | Unix 时间戳（SS2022 密钥依赖此字段） |
| `updated_at` | int | Unix 时间戳 |

> **⚠️ 关键规则：客户端连接用 `port`，不用 `server_port`**

---

## 3. Shadowsocks

**数据库表：** `v2_server_shadowsocks`

### 返回字段
```json
{
  "type": "shadowsocks",
  "cipher": "aes-256-gcm",
  "obfs": "http",
  "obfs-host": "www.example.com",
  "obfs-path": "/",
  "obfs_settings": {
    "host": "www.example.com",
    "path": "/"
  }
}
```

### cipher 取值
| 值 | 说明 |
|----|------|
| `aes-128-gcm` | 普通 AES |
| `aes-256-gcm` | 普通 AES |
| `chacha20-ietf-poly1305` | ChaCha20 |
| `2022-blake3-aes-128-gcm` | SS2022，密钥长度 16 字节 |
| `2022-blake3-aes-256-gcm` | SS2022，密钥长度 32 字节 |

### 密码生成规则
```
# 非 SS2022：
password = user.uuid

# SS2022（cipher 包含 "2022-blake3"）：
keyLen   = cipher == "2022-blake3-aes-128-gcm" ? 16 : 32
serverKey = base64( md5(server.created_at)[0..keyLen] )
userKey   = base64( user.uuid[0..keyLen] )
password  = "{serverKey}:{userKey}"
```

### obfs 字段说明
- `obfs == "http"` 时，才有 obfs 混淆
- `obfs-host` / `obfs-path` 是顶层字段（从 `obfs_settings` 展开）
- sing-box plugin 格式：`"plugin": "obfs-local"`, `"plugin_opts": "obfs=http;obfs-host=...;obfs-path=..."`

---

## 4. VMess

**数据库表：** `v2_server_vmess`

### 返回字段
```json
{
  "type": "vmess",
  "tls": 0,
  "tlsSettings": {
    "allowInsecure": 0,
    "serverName": "sni.example.com"
  },
  "network": "ws",
  "networkSettings": {
    "path": "/path",
    "headers": { "Host": "ws.example.com" },
    "serviceName": "grpc-service"
  }
}
```

> ⚠️ VMess 用**驼峰命名**：`tlsSettings`、`networkSettings`（其他协议用下划线）

### tls 字段
| 值 | 含义 |
|----|------|
| `0` | 无 TLS |
| `1` | 标准 TLS |

### network 取值
`tcp` / `ws` / `grpc` / `kcp` / `httpupgrade` / `xhttp`

### sing-box JSON
```json
{
  "type": "vmess",
  "server": "host",
  "server_port": 443,
  "uuid": "user-uuid",
  "security": "auto",
  "alter_id": 0,
  "tls": {
    "enabled": true,
    "insecure": false,
    "server_name": "sni"
  },
  "transport": {
    "type": "ws",
    "path": "/path",
    "headers": { "Host": "ws.example.com" },
    "max_early_data": 2048,
    "early_data_header_name": "Sec-WebSocket-Protocol"
  }
}
```

---

## 5. VLess（含 Reality）

**数据库表：** `v2_server_vless`

### 返回字段
```json
{
  "type": "vless",
  "tls": 2,
  "tls_settings": {
    "server_name": "sni.example.com",
    "allow_insecure": 0,
    "fingerprint": "chrome",
    "public_key": "base64-public-key",
    "short_id": "abcd1234"
  },
  "flow": "xtls-rprx-vision",
  "network": "tcp",
  "network_settings": {
    "path": "/path",
    "headers": { "Host": "example.com" },
    "serviceName": "grpc-service"
  }
}
```

> ⚠️ VLess 用下划线：`tls_settings`、`network_settings`

### tls 字段
| 值 | 含义 |
|----|------|
| `0` | 无 TLS |
| `1` | 标准 TLS |
| `2` | **Reality**（需提取 `public_key`、`short_id`、`fingerprint`） |

### Reality 必需字段（来自 `tls_settings`）
| 字段 | 说明 |
|------|------|
| `public_key` | ED25519 公钥，Base64 URL-Safe |
| `short_id` | 8 位十六进制字符串 |
| `fingerprint` | uTLS 指纹，如 `chrome` |
| `server_name` | SNI |

### sing-box JSON（Reality）
```json
{
  "type": "vless",
  "server": "host",
  "server_port": 443,
  "uuid": "user-uuid",
  "flow": "xtls-rprx-vision",
  "packet_encoding": "xudp",
  "tls": {
    "enabled": true,
    "server_name": "sni",
    "utls": {
      "enabled": true,
      "fingerprint": "chrome"
    },
    "reality": {
      "enabled": true,
      "public_key": "...",
      "short_id": "abcd1234"
    }
  }
}
```

---

## 6. Trojan

**数据库表：** `v2_server_trojan`

### 返回字段
```json
{
  "type": "trojan",
  "server_name": "sni.example.com",
  "allow_insecure": 0,
  "network": "tcp",
  "network_settings": {
    "serviceName": "grpc-service",
    "path": "/path",
    "headers": { "Host": "example.com" }
  }
}
```

> ⚠️ Trojan 的 TLS 配置是**顶层字段**（不在 `tls_settings` 里）：  
> `server_name` 和 `allow_insecure` 直接挂在 server 对象上

### 密码
```
password = user.uuid
```

### sing-box JSON
```json
{
  "type": "trojan",
  "server": "host",
  "server_port": 443,
  "password": "user-uuid",
  "tls": {
    "enabled": true,
    "insecure": false,
    "server_name": "sni"
  },
  "transport": {
    "type": "grpc",
    "service_name": "grpc-service"
  }
}
```

---

## 7. Hysteria v1 / v2

**数据库表：** `v2_server_hysteria`

> ⚠️ 后端 `type` 字段**始终返回 `"hysteria"`**，v1/v2 靠 `version` 字段区分

### 返回字段
```json
{
  "type": "hysteria",
  "version": 2,
  "up_mbps": 100,
  "down_mbps": 100,
  "server_name": "sni.example.com",
  "insecure": 0,
  "obfs": "salamander",
  "obfs_password": "obfs-password-here",
  "port": "8000-9000"
}
```

### version 字段规则
| `version` | 有效类型 | 密码字段 | sing-box type |
|-----------|---------|---------|---------------|
| `1` 或 `null` | Hysteria v1 | `auth_str` | `hysteria` |
| `2` | Hysteria v2 | `password` | `hysteria2` |

### TLS 配置字段（顶层，不在 tls_settings 里）
- `server_name` → SNI
- `insecure` → 允许不安全证书

### obfs 配置
| 字段 | Hysteria v1 | Hysteria v2 |
|------|-------------|-------------|
| `obfs` | 混淆密码字符串 | 混淆类型（如 `salamander`） |
| `obfs_password` | 不使用 | 混淆密码 |

### 端口处理
```
单端口：port = 443  → 直接使用
范围端口：port = "8000-9000"  → 客户端随机选取
          mport = "8000-9000"  → 原始范围字符串
```

### sing-box JSON（v1）
```json
{
  "type": "hysteria",
  "server": "host",
  "server_port": 443,
  "auth_str": "user-uuid",
  "up_mbps": 100,
  "down_mbps": 100,
  "obfs": "obfs-password",
  "tls": {
    "enabled": true,
    "insecure": false,
    "server_name": "sni",
    "alpn": ["h3"]
  }
}
```

### sing-box JSON（v2）
```json
{
  "type": "hysteria2",
  "server": "host",
  "server_port": 443,
  "password": "user-uuid",
  "obfs": {
    "type": "salamander",
    "password": "obfs-password"
  },
  "tls": {
    "enabled": true,
    "insecure": false,
    "server_name": "sni",
    "alpn": ["h3"]
  }
}
```

---

## 8. TUIC

**数据库表：** `v2_server_tuic`

### 返回字段
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

### sing-box JSON
```json
{
  "type": "tuic",
  "server": "host",
  "server_port": 443,
  "uuid": "user-uuid",
  "password": "user-uuid",
  "congestion_control": "cubic",
  "udp_relay_mode": "native",
  "zero_rtt_handshake": false,
  "tls": {
    "enabled": true,
    "insecure": false,
    "server_name": "sni",
    "alpn": ["h3"],
    "disable_sni": false
  }
}
```

---

## 9. AnyTLS

**数据库表：** `v2_server_anytls`

### 返回字段
```json
{
  "type": "anytls",
  "server_name": "sni.example.com",
  "insecure": 0,
  "padding_scheme": null
}
```

### sing-box JSON
```json
{
  "type": "anytls",
  "server": "host",
  "server_port": 443,
  "password": "user-uuid",
  "tls": {
    "enabled": true,
    "insecure": false,
    "server_name": "sni",
    "alpn": ["h2", "http/1.1"]
  }
}
```

---

## 10. 用户认证与密钥规则

### UUID 用途（按协议）
| 协议 | 字段名 | 值 |
|------|-------|----|
| Shadowsocks（普通） | `password` | `user.uuid` |
| Shadowsocks（SS2022） | `password` | `serverKey:userKey` |
| VMess | `uuid` | `user.uuid` |
| VLess | `uuid` | `user.uuid` |
| Trojan | `password` | `user.uuid` |
| Hysteria v1 | `auth_str` | `user.uuid` |
| Hysteria v2 | `password` | `user.uuid` |
| TUIC | `uuid` + `password` | `user.uuid` |
| AnyTLS | `password` | `user.uuid` |

### SS2022 密钥算法
```
keyLen    = (cipher == "2022-blake3-aes-128-gcm") ? 16 : 32
serverKey = Base64( MD5(server.created_at)[0..keyLen] )
userKey   = Base64( user.uuid[0..keyLen] )
password  = serverKey + ":" + userKey
```

### Base64 URL-Safe 规则（Reality 公钥等）
```
encode: replace(+→-, /→_, 去掉=)
decode: replace(-→+, _→/), 补齐=号后 base64decode
```

---

## 11. 特殊处理逻辑

### 域名替换（自研客户端）
```
User-Agent 含 "velox/" → host 中 "vazxnet.fun" 替换为 "vmzxnsj.space"
```

### port vs server_port 规则
```
port        = 客户端连接端口（可以是范围字符串）
server_port = 后端监听端口（整数）
mport       = 多端口原始字符串（port 含范围时才存在）

客户端连接用 port（或从 mport 随机选取）
```

### tls 字段值（各协议）
| 值 | VMess | VLess | Trojan | Hysteria |
|----|-------|-------|--------|---------|
| `"0"` | 无 TLS | 无 TLS | — | — |
| `"1"` | 标准 TLS | 标准 TLS | — | — |
| `"2"` | — | **Reality** | — | — |
| 无此字段 | — | — | 始终 TLS | 始终 TLS |

### TLS 配置字段位置（各协议不同！）
| 协议 | TLS 配置位置 |
|------|-------------|
| VMess | `tlsSettings.serverName`, `tlsSettings.allowInsecure` |
| VLess | `tls_settings.server_name`, `tls_settings.allow_insecure` |
| Trojan | **顶层** `server_name`, `allow_insecure` |
| Hysteria | **顶层** `server_name`, `insecure` |
| TUIC | **顶层** `server_name`, `insecure` |
| AnyTLS | **顶层** `server_name`, `insecure` |

### Hysteria type 区分
```
后端始终返回 type = "hysteria"
客户端需要：
  version == 1 或 null → sing-box type = "hysteria",  密码字段 auth_str
  version == 2         → sing-box type = "hysteria2", 密码字段 password
```

### 在线状态判断
```
is_online = (now() - 300 > last_check_at) ? 0 : 1
# 即：300 秒内有心跳 = 在线
```

---

## 12. 数据库表字段映射

### v2_server_shadowsocks
```
id, group_id(JSON), name, rate, host, port, server_port,
cipher, obfs, obfs_settings(JSON),
show, sort, parent_id, tags(JSON), created_at, updated_at
```

### v2_server_vmess
```
id, group_id(JSON), name, rate, host, port, server_port,
tls, tlsSettings(JSON), network, networkSettings(JSON),
ruleSettings(JSON), dnsSettings(JSON),
show, sort, parent_id, tags(JSON), created_at, updated_at
```

### v2_server_vless
```
id, group_id(JSON), name, rate, host, port, server_port,
tls, tls_settings(JSON), flow, network, network_settings(JSON),
show, sort, parent_id, tags(JSON), created_at, updated_at
```

### v2_server_trojan
```
id, group_id(JSON), name, rate, host, port, server_port,
network, network_settings(JSON), allow_insecure, server_name,
show, sort, parent_id, tags(JSON), created_at, updated_at
```

### v2_server_hysteria
```
id, group_id(JSON), name, rate, host, port, server_port,
version, up_mbps, down_mbps, obfs, obfs_password,
server_name, insecure,
show, sort, parent_id, tags(JSON), created_at, updated_at
```

### v2_server_tuic
```
id, group_id(JSON), name, rate, host, port, server_port,
server_name, insecure, disable_sni,
udp_relay_mode, zero_rtt_handshake, congestion_control,
show, sort, parent_id, tags(JSON), created_at, updated_at
```

### v2_server_anytls
```
id, group_id(JSON), name, rate, host, port, server_port,
server_name, insecure, padding_scheme(JSON),
show, sort, parent_id, tags(JSON), created_at, updated_at
```

---

## 13. ServerService 合并逻辑

### getAvailableServers() 流程
```
1. 合并所有协议节点（array_merge）
2. 过滤：show=1 且 用户在 group_id 内
3. 统一后处理：
   - port 含范围 → mport 保存原始值，port 随机取值
   - is_online 计算
   - cache_key 生成
4. obfs 展开：
   - SS obfs_settings['host'] → 顶层 'obfs-host'
   - SS obfs_settings['path'] → 顶层 'obfs-path'
5. tls_settings 清理：
   - VLess tls_settings 中移除 private_key（不返回给客户端）
6. 域名替换（自研客户端 UA）
```

---

## 14. Singbox 配置生成对照

### 版本判断
```
User-Agent: sing-box/1.12.0 → 使用 Singbox.php（新版）
User-Agent: sing-box/1.8.0  → 使用 SingboxOld.php（旧版）
```

### 端口使用规则（Singbox.php buildXxx）
```php
$server['port']  // 客户端连接端口（正确）
// 不使用 server_port
```

### 所有协议 buildXxx 方法产出字段汇总

| 协议 | sing-box type | 密码字段 | TLS | transport |
|------|--------------|---------|-----|-----------|
| SS | `shadowsocks` | `password` | 无 | plugin |
| VMess | `vmess` | `uuid` | `tls{}` | `transport{}` |
| VLess | `vless` | `uuid` | `tls{reality{}}` | `transport{}` |
| Trojan | `trojan` | `password` | `tls{}` | `transport{}` |
| Hysteria v1 | `hysteria` | `auth_str` | `tls{}` | 无 |
| Hysteria v2 | `hysteria2` | `password` | `tls{}` | 无，`obfs{}` |
| TUIC | `tuic` | `uuid`+`password` | `tls{}` | 无 |
| AnyTLS | `anytls` | `password` | `tls{}` | 无 |

---

## 15. 客户端已知 Bug 清单

> 已修复的标 ✅，待修复或需核实的标 ⚠️

### ✅ 已修复

| # | 问题 | 文件 | 修复内容 |
|---|------|------|---------|
| 1 | **端口优先级反转** | `config_generator.dart:332` | `server['server_port']` 优先改为 `server['port']` 优先 |
| 2 | **tls='2' 不识别** | `config_generator.dart:340` | 加入 `server['tls'] == '2'` 判断 |
| 3 | **Reality 配置未生成** | `singbox_config.dart`, `outbound_builder.dart`, `config_generator.dart` | 新增 `RealityConfig`，从 `tls_settings` 提取 `public_key`/`short_id`/`fingerprint` |
| 4 | **Hysteria v1/v2 不区分** | `vpn_bloc.dart` | 检查 `server.version`，version=2 时用 `hysteria2` + `password` |
| 5 | **Hysteria 带宽未传递** | `vpn_bloc.dart` | `up_mbps`/`down_mbps` 注入 `protocol_settings` |
| 6 | **Trojan TLS 字段丢失** | `vpn_bloc.dart` | `server.serverName` / `server.allowInsecure` 合并到 `tls_settings` |
| 7 | **Hysteria TLS 字段丢失** | `vpn_bloc.dart` | `server.serverName` / `server.insecure` 合并到 `tls_settings` |
| 8 | **node_unreachable 静默** | `home_page.dart` | 改为弹 SnackBar 提示 |

### ⚠️ 待确认 / 可能仍有问题

| # | 问题 | 说明 |
|---|------|------|
| 9 | **SS obfs 字段名不匹配** | 后端展开到顶层 `obfs-host`/`obfs-path`，但 `ServerModel` 有 `obfsSettings` map；`config_generator.dart` 里查 `plugin`/`plugin_opts`，实际应转换为 sing-box plugin 格式 |
| 10 | **VMess tlsSettings 驼峰** | `ServerModel.fromJson` 已做 `tlsSettings→tls_settings` 转换，但 `tlsSettings.allowInsecure`（驼峰）和 `tlsSettings.serverName`（驼峰）是否正确被提取到 `tls_settings` 里需验证 |
| 11 | **TUIC 协议未实现** | `config_generator.dart` 无 `tuic` case，会抛 `UnsupportedError` |
| 12 | **AnyTLS 协议未实现** | `config_generator.dart` 无 `anytls` case，会抛 `UnsupportedError` |
| 13 | **Hysteria obfs 格式** | v1 的 `obfs` 是字符串密码，v2 的 `obfs` 是类型名 + `obfs_password` 是密码；当前 `_serverToConfigMap` 透传 `server.obfsSettings`，但后端 Hysteria 的 obfs 不在 `obfsSettings` 里，在顶层 `obfs`/`obfs_password` 字段 |
| 14 | **多端口 mport 未处理** | `port` 为范围字符串时客户端应随机选取，目前直接用 `server.port` 转 int 会失败 |
| 15 | **VLess packet_encoding** | 后端生成时加了 `"packet_encoding": "xudp"`，客户端未设置 |
| 16 | **VMess early_data** | 后端 WS transport 加了 `max_early_data: 2048`，客户端未设置 |
