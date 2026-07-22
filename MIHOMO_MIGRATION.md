# sing-box → Mihomo 内核替换方案

## 一、现状分析

### 当前架构

```
Flutter UI (vpn_bloc.dart)
        ↓  serverConfig Map
SingboxService.connect()          ← Dart 层（纯 Dart）
        ↓  config JSON string
MethodChannel (com.velox.singbox_flutter/method)
        ↓
SingboxFlutterPlugin.swift        ← macOS 原生层
        ↓  启动子进程
sing-box 二进制 (macos/Resources/sing-box, 62MB)
        ↓  Clash API HTTP
fetchClashStats() → 127.0.0.1:19090/connections
```

### 涉及文件清单

| 文件 | 作用 | 改动类型 |
|------|------|----------|
| `macos/Resources/sing-box` | VPN 内核二进制 | 替换为 `mihomo` |
| `packages/singbox_flutter/lib/src/singbox_config.dart` | sing-box JSON 配置模型 | 废弃，新建 mihomo 配置 |
| `packages/singbox_flutter/lib/src/config_generator/config_generator.dart` | 生成 JSON 配置 | 废弃，新建 mihomo 生成器 |
| `packages/singbox_flutter/lib/src/config_generator/outbound_builder.dart` | 协议出站配置 | 废弃，逻辑迁移到新生成器 |
| `packages/singbox_flutter/lib/src/singbox_service.dart` | Flutter ↔ 原生通信 | 改调新生成器 |
| `packages/singbox_flutter/lib/singbox_flutter.dart` | 导出文件 | 更新 export |
| `packages/singbox_flutter/macos/Classes/SingboxFlutterPlugin.swift` | macOS 原生插件 | 改二进制路径/参数/配置格式 |

---

## 二、配置格式差异

### sing-box（现在）→ Mihomo（目标）

```
sing-box JSON                     Mihomo YAML
─────────────────────────────     ──────────────────────────────
{                                 mixed-port: 10808
  "inbounds": [{                  mode: global
    "type": "mixed",              log-level: info
    "listen_port": 10808          external-controller: 127.0.0.1:9090
  }],
  "outbounds": [{                 proxies:
    "type": "vless",               - name: proxy
    "tag": "proxy",                  type: vless
    "server": "...",                 server: ...
    "tls": {                         tls: true
      "reality": {                   reality-opts:
        "public_key": "..."            public-key: ...
      }
    }
  }],
  "route": {                      rules:
    "final": "proxy",              - MATCH,PROXY
    "rules": [...]
  },
  "experimental": {               external-controller: 127.0.0.1:9090
    "clash_api": {...}
  }
}
```

### 关键差异汇总

| 维度 | sing-box | Mihomo |
|------|----------|--------|
| 配置格式 | JSON | YAML |
| 启动命令 | `sing-box run -c config.json` | `mihomo -f config.yaml -d /tmp/mihomo` |
| 版本查询 | `sing-box version` | `mihomo -v` |
| Clash API 端口 | 19090（实验性） | 9090（原生） |
| 系统代理设置 | 配置里 `set_system_proxy: true` | 不管，由 Swift Helper 设置 |
| TUN 配置位置 | `inbounds[].type == "tun"` | 顶层 `tun.enable: true` |
| 流量统计 API | `/connections`（实验） | `/connections`（原生） |
| DNS 配置 | `dns.servers[].detour` | `dns.nameserver` + `nameserver-policy` |
| 路由规则 | `route.rules[].outbound` | `rules: [GEOIP,CN,DIRECT]` |

---

## 三、协议支持对比

| 协议 | sing-box | Mihomo | 备注 |
|------|----------|--------|------|
| Shadowsocks | ✅ | ✅ | |
| VMess | ✅ | ✅ | |
| VLESS | ✅ | ✅ | |
| VLESS + Reality | ✅ | ✅ | Mihomo 1.18+ |
| VLESS + XTLS | ✅ | ✅ | `flow: xtls-rprx-vision` |
| Trojan | ✅ | ✅ | |
| Hysteria | ✅ | ✅ | |
| Hysteria2 | ✅ | ✅ | |
| TUIC | ✅ | ✅ | |
| AnyTLS | ✅ | ❌ | Mihomo 不支持，需降级提示 |

---

## 四、Mihomo 配置示例（目标格式）

### 全局代理模式（global）

```yaml
mixed-port: 10808
allow-lan: false
mode: global
log-level: info
ipv6: false
external-controller: 127.0.0.1:9090

dns:
  enable: true
  ipv6: false
  enhanced-mode: redir-host
  nameserver:
    - tls://8.8.8.8
    - tls://1.1.1.1

proxies:
  - name: proxy
    type: vless
    server: sg.example.com
    port: 443
    uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    tls: true
    servername: sg.example.com
    network: tcp
    flow: xtls-rprx-vision
    reality-opts:
      public-key: xxxxxxxxxxxx
      short-id: xxxxxxxx
    client-fingerprint: chrome

proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - proxy

rules:
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - DOMAIN-SUFFIX,sg.example.com,DIRECT
  - MATCH,PROXY
```

### 规则代理模式（rule）

```yaml
mixed-port: 10808
mode: rule
...

rules:
  - GEOIP,CN,DIRECT,no-resolve
  - GEOSITE,CN,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - MATCH,PROXY
```

---

## 五、实施步骤

### Step 1 — 下载 Mihomo 二进制（macOS Universal）
- 从 Mihomo releases 下载 `mihomo-darwin-universal`
- 放到 `macos/Resources/mihomo`（替代 `sing-box`）
- 赋予可执行权限

### Step 2 — 新建 Dart 配置层
新建以下文件（不删原文件，保持编译无破坏）：
- `lib/src/mihomo_config.dart` — YAML 配置 Map 构建器
- `lib/src/mihomo_config_generator.dart` — 从 serverConfig 生成 Mihomo YAML

### Step 3 — 修改 `singbox_service.dart`
- 将 `SingboxConfigGenerator.generate()` 替换为 `MihomoConfigGenerator.generate()`
- 配置内容从 JSON string 变为 YAML string（`'config'` key 保持不变，内容格式换了）

### Step 4 — 修改 `SingboxFlutterPlugin.swift`
以下函数需改动：

```swift
// 改 1：二进制路径
getSingboxPath() → getMihomoPath()
// "sing-box" → "mihomo"

// 改 2：启动参数
process.arguments = ["run", "-c", configPath]
→
process.arguments = ["-f", configPath, "-d", mihomoWorkDir]

// 改 3：版本查询参数
task.arguments = ["version"]
→
task.arguments = ["-v"]

// 改 4：配置文件路径
getConfigFilePath() → "/tmp/mihomo_config.yaml"

// 改 5：sanitizeDesktopConfig() 不再需要（Mihomo 不设置系统代理）
// 直接透传 YAML config

// 改 6：TUN 检测（现在解析 JSON inbounds，改为检测 YAML 字段）
// "tun:\n  enable: true" 替代 inbounds[].type == "tun"

// 改 7：Clash API 端口
let clashApiPort = 19090 → 9090

// 改 8：TUN 模式的 helper 命令 key
// "singbox" → "mihomo"（helper 接收的 start_tun 命令参数 key）
```

### Step 5 — 更新 Helper（如果支持 TUN）
`macos/Helper/VeloxHelper.c` 里处理 `start_tun` 的代码使用的 key 是 `singbox`，需改为 `mihomo`（或改成通用的 `binary`）。

### Step 6 — 测试验证
1. 启动 `mihomo -f /tmp/mihomo_config.yaml -d /tmp/mihomo`
2. 验证 `curl -x http://127.0.0.1:10808 https://www.google.com`
3. 验证 `curl http://127.0.0.1:9090/connections`（流量统计 API）

---

## 六、风险与注意事项

### 风险 1：AnyTLS 协议不支持
Mihomo 不支持 AnyTLS 协议。如果用户节点是 AnyTLS，连接会失败。
**处置**：在 `MihomoConfigGenerator` 里检测到 AnyTLS 时抛出有意义的错误提示。

### 风险 2：Helper TUN 命令 key 不一致
当前 Helper 代码里 TUN 启动命令用 `"singbox"` 作为二进制路径的 key，
改成 Mihomo 后需要同步更新 Helper C 代码，否则 TUN 模式启动失败。

### 风险 3：Mihomo YAML 格式严格
YAML 缩进错误会导致 Mihomo 直接退出，报 `invalid config`。
**处置**：在 Swift 层捕获进程快速退出，读取日志文件，输出给 Flutter 层。

### 风险 4：GeoIP/GeoSite 数据库
Mihomo 使用 `.mmdb` 格式（GeoLite2），sing-box 用 `.srs` 格式（二进制规则集）。
规则模式下需要确保 Mihomo 的工作目录有 `Country.mmdb`，
或者改用在线订阅规则（`geosite: cn`）。
**处置**：工作目录设为 `/tmp/mihomo`，Mihomo 会自动下载 GeoIP 库（需网络）；
或内置 `Country.mmdb` 到 Bundle Resources。

### 风险 5：YAML 序列化无现成 Dart 库
`singbox_config.dart` 用 Dart 内置 `dart:convert` JSON 序列化，YAML 没有内置支持。
**处置**：直接拼接 YAML 字符串（Mihomo 配置结构固定，不需要通用 YAML 库）。

---

## 七、不需要改的部分

- `MethodChannel` 名称 (`com.velox.singbox_flutter/method`) — 保持不变
- `EventChannel` 名称 — 保持不变  
- `SingboxStatus`、`SingboxStats` — 完全不变
- `vpn_bloc.dart`、UI 层 — 完全不变
- macOS `PrivilegedHelper`（IPC 通信机制）— 不变
- `warmupAuth`、`uninstallHelper` — 不变
- `applyProxySettings` / `clearProxySettings` — 不变（依然由 Swift 设置系统代理）

---

## 八、工程量估计

| 步骤 | 预估时间 |
|------|----------|
| 下载并嵌入 Mihomo 二进制 | 30 分钟 |
| 新建 Dart 配置生成器（YAML） | 2-3 小时 |
| 修改 Swift 插件（路径/参数/TUN检测） | 1 小时 |
| 测试联调 | 1-2 小时 |
| **合计** | **半天～一天** |
