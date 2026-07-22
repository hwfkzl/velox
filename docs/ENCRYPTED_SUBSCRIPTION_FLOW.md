# Velox 加密订阅完整流程（客户端 ↔ V2Board 后端）

**对标**：`lol/AppController::appsync` 的独立 RPC + 加密响应模式
**目的**：让运营商/单位内网审计/DPI 无法从订阅响应中识别 VPN 节点特征
**落地日期**：2026-04-18

---

## 架构边界

```
┌─────────── Velox 客户端（Flutter + mihomo）──────────────┐
│                                                           │
│  [阶段1] 登录                                              │
│     ↓  POST /passport/auth/login                          │
│  [阶段2] 用户信息                                          │
│     ↓  GET /user/info                                     │
│  [阶段3] 加密订阅  ★                                      │
│     ↓  POST /client/velox/sync                            │
│     ← { sub:"<AES密文>" }                                 │
│     ← 本地解密 → ServerModel[]                             │
│                                                           │
│  [阶段4] 用户选节点 (本地)                                  │
│  [阶段5] MihomoConfigGenerator 本地生 YAML (本地)           │
│  [阶段6] Swift 启动 mihomo 内核 (本地)                      │
│  [阶段7] 流量走 mihomo → VLESS+Reality → 节点              │
│  [阶段8] 切节点 (mihomo RESTful API, 本地)                  │
│  [阶段9] 断开 (本地)                                       │
└───────────────────────────────────────────────────────────┘

┌──────────── V2Board 后端 ────────────────────────────────┐
│                                                           │
│  /passport/auth/login   → 发 auth_data token              │
│  user middleware        → decryptAuthData → $request->user│
│  /user/info             → 套餐 / 流量 / 过期              │
│  /client/velox/sync ★   → ServerService + AES 加密        │
│  /server/UniProxy/*     → 和节点侧同步，客户端不感知       │
└───────────────────────────────────────────────────────────┘

┌──────────── 节点服务器（xray-core）────────────────────────┐
│  - 监听真实 IP:port                                         │
│  - Reality + VLESS + xtls-rprx-vision 加密                  │
│  - 校验 uuid + public_key + short_id                        │
│  - 定期从 V2Board 拉用户 / 上报流量                          │
└───────────────────────────────────────────────────────────┘
```

---

## 阶段 0：App 启动（未登录）

| 步骤 | 客户端（Flutter） | 后端 |
|---|---|---|
| 0.1 | `main.dart` 初始化 DI、日志、UA | — |
| 0.2 | 读取 `SecureStorage` 里的 `authToken` | — |
| 0.3 | 有 token → 跳首页；无 token → 跳登录页 | — |

**涉及文件**
- 客户端：`lib/main.dart`、`lib/di/injection.dart`、`lib/core/storage/secure_storage.dart`

---

## 阶段 1：登录

```
Flutter → POST /api/v1/passport/auth/login  {email, password, captcha_data?}
                ↓
  AuthController::login
    ├─ UserService::getEncryptUserPassword 校验密码
    ├─ 检查 banned / 黑名单
    ├─ AuthService::generateAuthData($user) 生成加密 token
    └─ 返回 { data: { token, auth_data, is_admin } }
                ↓
Flutter ← 保存 auth_data 到 SecureStorage（key: authToken）
        ← 跳转首页
```

**关键点**
- `auth_data` 是**加密字符串**（AES + 时间戳 + user_id），不是 `user.token` 原值
- 每次请求 ApiClient interceptor 自动把它塞进 `Authorization` header
- 后端 `user` middleware 用 `AuthService::decryptAuthData` 反向解出 User

**涉及文件**
- 客户端：`lib/data/datasources/remote/auth_remote_datasource.dart`、`lib/core/network/api_client.dart:57-67`
- 后端：`app/Services/AuthService.php`、`app/Http/Middleware/User.php`、`app/Http/Controllers/V1/Passport/AuthController.php`

---

## 阶段 2：加载用户信息

```
Flutter → GET /api/v1/user/info        Authorization: <auth_data>
                ↓
  user middleware: decryptAuthData → $request->user
                ↓
  UserController::info 返回套餐 / 流量 / 过期时间
                ↓
Flutter ← UserModel 存进 `_cachedUserInfo`（内存 + LocalStorage）
```

关键字段：`uuid`（给 VLESS 用）、`transfer_enable`（总流量）、`expired_at`（过期）、`plan_id`、`u`/`d`（已用上下行）。

**涉及文件**
- 客户端：`lib/data/datasources/remote/user_remote_datasource.dart`、`lib/data/repositories/user_repository_impl.dart`
- 后端：`app/Http/Controllers/V1/User/UserController.php::info`

---

## 阶段 3：拉加密订阅 ★ 核心

```
Flutter → POST /api/v1/client/velox/sync   Authorization: <auth_data>  Body: {}
   (ServerRepositoryImpl.getServerList
     → ServerRemoteDataSourceImpl.getServerList
       → VeloxSyncDataSourceImpl.fetchServers)
                ↓
  user middleware: decryptAuthData → $request->user
                ↓
  VeloxController::sync
    ├─ UA 校验 velox/                   (阻挡非 Velox 客户端)
    ├─ User::find($request->user['id'])
    ├─ UserService::isAvailable($user)  (检查是否过期/封号)
    ├─ ServerService::getAvailableServers($user)
    │      └─ 查 DB：按 user.group_id + plan 过滤可见节点
    ├─ 节点域名替换 vazxnet.fun → vmzxnsj.space (国内入口域名)
    ├─ json_encode({data: servers})
    ├─ SubCrypto::encrypt(json)         AES-128-CBC
    │      └─ key: velox_subkey_16b, iv: 2a1b3c4d5e6f7890
    └─ 返回 { status:1, msg:"Success", sub:"<32KB base64>", updated_at }
                ↓
Flutter ← SubCryptoService.decrypt(sub)
        ← jsonDecode → {"data":[...]}
        ← ServerModel.fromJson × N
        ← ServerRepositoryImpl 缓存（内存 + LocalStorage）
```

**涉及文件**
- 客户端：
  - `lib/data/datasources/remote/velox_sync_datasource.dart`
  - `lib/core/services/sub_crypto_service.dart`
  - `lib/data/datasources/remote/server_remote_datasource.dart`
  - `lib/data/repositories/server_repository_impl.dart`
- 后端：
  - `app/Http/Controllers/V1/Client/VeloxController.php`
  - `app/Utils/SubCrypto.php`
  - `app/Services/ServerService.php`
  - `app/Http/Routes/V1/ClientRoute.php`

**加密参数（双端严格对齐）**
```
算法：AES-128-CBC
Key ：velox_subkey_16b    (16 字节 ASCII)
IV  ：2a1b3c4d5e6f7890    (16 字节 ASCII)
填充：PKCS7 (OpenSSL 默认)
输出：Base64 字符串（存放在 sub 字段）
```

**加密前 / 后对比（DPI 视角）**

| | 传统 `/user/server/fetch` 明文 | 我们的 `/client/velox/sync` 密文 |
|---|---|---|
| HTTP body | `{"data":[{"host":"18.163.128.70","type":"vless","flow":"xtls-rprx-vision","tls_settings":{"public_key":"rDmGv4gLlc50...","server_name":"www.microsoft.com"}}]}` | `{"status":1,"sub":"ibi81UB1H4MlWU+CwvcJ9auzaIsQHZv8...(32KB base64)","updated_at":...}` |
| DPI 可识别字段 | vless / trojan / public_key / host IP / server_name | **无** |
| 识别成本 | 正则一秒命中 | 需要 AES key 才能识别 |
| 被通报风险 | 高 | 极低（单次抓包无关键词匹配） |

---

## 阶段 4：用户选节点

```
nodes_page 点击某节点
  ↓
NodeBloc.emit(selectedServer)
  ↓
用户点连接按钮
  ↓
VpnBloc._onConnectRequested(server, allServers)
```

无后端调用。

**涉及文件**：`lib/presentation/pages/nodes/nodes_page.dart`、`lib/presentation/blocs/node/node_bloc.dart`、`lib/presentation/blocs/vpn/vpn_bloc.dart`

---

## 阶段 5：本地生成 mihomo YAML

```
VpnBloc._onConnectRequested
  ├─ 读 SharedPreferences 的 proxyMode (rule/global/tun)
  ├─ _serverToConfigMap(server, userUuid)  ← 把 ServerModel 转为 Map
  ├─ 打包 all_servers 数组（所有节点，方便后面切换）
  ├─ MihomoService.connect(serverConfig)
  │     ├─ MihomoConfigGenerator.generate(
  │     │    servers: allServersConfig,
  │     │    selectedServerId: selectedId,
  │     │    options: {platform: macos, proxyMode, routingMode}
  │     │  )
  │     │  ★ 纯本地 Dart 代码拼 YAML，完全不依赖后端
  │     │    产出一份 ~3KB 的 Clash.Meta YAML，含：
  │     │      - proxies (N 个节点配置，含 vless + reality)
  │     │      - proxy-groups (PROXY 选择器)
  │     │      - rules (分流规则)
  │     │      - dns (fake-ip + 国内直连)
  │     │      - tun (若启用)
  │     │      - mixed-port 17890
  │     │
  │     └─ MethodChannel.invokeMethod('connect', {config: yaml, selectedProxyName})
```

无后端调用。

**涉及文件**：`packages/singbox_flutter/lib/src/mihomo_service.dart`、`packages/singbox_flutter/lib/src/mihomo_config_generator.dart`

**和 lol 的架构差异**：
- lol 的 YAML **在服务端生成并加密下发**
- Velox 的 YAML **在客户端本地生成**（后端只传节点 JSON）
- 好处：平台差异化（TUN/macOS/Windows 各自适配）
- 成本：分流规则变更必须发 App 版本，不能热更

---

## 阶段 6：启动 mihomo 内核

```
MethodChannel → macOS Swift 层（SingboxFlutterPlugin）
  ├─ 写 yaml 到 /tmp/velox_mihomo.yaml
  ├─ 区分 TUN 模式 / 代理模式
  ├─ 代理模式：
  │    └─ 启动 mihomo 子进程 (path: Resources/mihomo)
  │         ├─ 监听 127.0.0.1:17890 (HTTP mixed-port)
  │         └─ 监听 127.0.0.1:19090 (控制器 RESTful API)
  │    └─ 通过 helper 调 networksetup 设系统代理 → 127.0.0.1:17890
  ├─ TUN 模式：
  │    └─ 通过 root LaunchDaemon helper 启动 mihomo with TUN enabled
  │         （需要特权操作网卡）
  └─ sendStatus(connected)
       ↓
Flutter ← status 事件 → VpnBloc emit VpnStatus.connected
       ← stats 事件 → 显示上下行速度
```

**涉及文件**：
- 客户端：`packages/singbox_flutter/macos/Classes/SingboxFlutterPlugin.swift`、`macos/Runner/Helpers/VeloxHelper.c`
- **内核文件**：`build/macos/.../Velox.app/Contents/Resources/mihomo`（原生二进制）

---

## 阶段 7：流量穿过 mihomo → 节点

```
浏览器 → 系统代理 127.0.0.1:17890 (mihomo)
           ↓ 匹配 rules
mihomo → TCP 到 174.138.28.73:38111 (新加坡节点真实 IP)
           ↓ TLS 握手 SNI=www.microsoft.com (Reality 伪装)
           ↓ VLESS + xtls-rprx-vision 加密
节点服务器 (xray-core)
  ├─ Reality 握手校验 public_key + short_id
  ├─ 校验 uuid（用户身份）
  ├─ 流量代发到目标域名 (google.com / youtube.com / ...)
  ├─ 计量上下行
  └─ 异步上报到 V2Board
           ↓
V2Board UniProxy 接口（节点↔后端）:
  - GET /api/v1/server/UniProxy/user    (节点拉用户列表，节点本地缓存)
  - POST /api/v1/server/UniProxy/push   (节点上报流量)
  - GET /api/v1/server/UniProxy/config  (节点拉自己的配置)
```

**涉及文件**
- 后端：`app/Http/Controllers/V1/Server/UniProxyController.php`、`app/Http/Routes/V1/ServerRoute.php`
- 这一层**客户端完全不参与**，是节点运维自动进行的

---

## 阶段 8：切节点（无缝）

```
NodesPage 点另一个节点
  ↓
VpnBloc._onConnectRequested（检测到已连接）
  ↓
MihomoService.switchProxy(proxyName: 'proxy-1')
  ↓
Swift 层 → HTTP PUT 127.0.0.1:19090/proxies/PROXY
           body: {"name":"proxy-1"}
  ↓
mihomo 直接切 selector，不需要重启、不重建 TUN
  ↓
后续流量立刻走新节点
```

原子操作，~10ms。如果切换的节点不在 `all_servers` 里（比如新拉了订阅有新节点），会 fallback 到完整重连。

**涉及文件**：`packages/singbox_flutter/lib/src/mihomo_service.dart::switchProxy`

---

## 阶段 9：断开

```
用户点断开
  ↓
VpnBloc._onDisconnectRequested
  ↓
MihomoService.disconnect()
  ↓
Swift 层:
  ├─ 关闭系统代理 (networksetup)
  ├─ kill mihomo 子进程 / 停 TUN
  └─ sendStatus(disconnected)
  ↓
VpnBloc emit VpnStatus.disconnected
```

无后端调用。

---

## 威胁模型与防护矩阵

| 威胁来源 | 此前（明文订阅） | 现在（加密订阅） |
|---|---|---|
| 运营商 DPI 识别"VPN 订阅" | ❌ body 里命中 vless/trojan 等关键词 | ✅ 全部密文，无关键词匹配 |
| 单位内网 HTTPS 审计（MITM 有证书） | ❌ 明文 JSON 直接暴露 | ✅ 仍是加密 base64 |
| 抓包留证据 | ❌ 可归因的明文节点列表 | ⚠️ 需破 AES 才能归因 |
| 加密方逆向客户端拿 key | ❌（key 写死在代码里） | 同 `lol/AppController`，接受的设计代价 |
| GFW 通过 TLS SNI 识别被封域名 | — | 这是协议层问题，加密不解决（靠 Reality/伪装） |
| 节点 IP 被封 | — | 靠多域名池 + 国内中转，不是加密解决 |

**结论**：加密订阅是"防通报"的**必要但非充分条件**，配合协议伪装（Reality）和国内中转链路一起工作。

---

## 抓包调试（Charles/Proxyman/mitmproxy）

客户端 `ApiClient` 内置了调试代理开关：

```bash
# 打开 Charles（或 Proxyman），启用 SSL Proxying for test.jsm.lol
# 然后：
flutter run -d macos --dart-define=PROXY=127.0.0.1:8888
```

这会让 Flutter 的所有 HTTPS 请求走 Charles，同时自动放行 Charles 的自签证书（仅 debug 模式）。

**正式构建不要带 `--dart-define=PROXY`**。

位置：`lib/core/network/api_client.dart::_setupDebugProxy`

---

## 加密密钥管理

**当前**（为和 lol 对齐，简单硬编码）：
- `rear后/app/Utils/SubCrypto.php::KEY / IV`
- `lucky/lib/core/services/sub_crypto_service.dart::_key / _iv`

两侧**必须严格一致**，任一修改后需要双端同步并重新部署。

**未来可能的加强**（非必须）：
- 换成 `openssl rand -hex 16` 生成的 16 字节随机二进制（现在是 ASCII，熵低）
- 改用 AES-256-GCM 带认证（防篡改）
- 用 HKDF 从 master secret 按用户 token 派生 per-user key

不做也够用 —— 威胁模型是 DPI 不是密码学攻击。

---

## 和 lol AppController 的架构对照

| 维度 | lol/AppController::appsync | Velox/VeloxController::sync |
|---|---|---|
| 端点形式 | POST 独立 RPC | POST 独立 RPC ✅ |
| 响应形态 | JSON + 加密字段 | JSON + 加密 `sub` 字段 ✅ |
| UA 校验 | globalfast/ | velox/ ✅ |
| 加密算法 | AES-128-CBC | AES-128-CBC ✅ |
| Key/IV | 硬编码在源码 | 硬编码在源码 ✅ |
| 鉴权方式 | token 在 POST body | `auth_data` 在 Authorization header |
| 加密载荷 | YAML（clash 字段）+ 节点数组（configsNodes 字段） | 节点 JSON（sub 字段） |
| 客户端 YAML 生成 | 否（直接用后端下发的 YAML） | **是**（本地 MihomoConfigGenerator） |

核心防护强度等同，Velox 保留了本地 YAML 生成的灵活性。

---

## 验收证据（2026-04-18 落地测试）

1. ✅ curl 命中 `/velox/sync` 返回 200 + 32KB base64 `sub`
2. ✅ openssl CLI 用同 key/iv 成功解密为 `{"data":[...]}`
3. ✅ Flutter 真机（macOS）登录 → 拉订阅 → 解密 → 启动 mihomo → 走新加坡节点访问 google.com 成功
4. ✅ Charles 抓包 `/velox/sync` 响应 body 全部为 base64 密文，无 vless/trojan/public_key 等关键词
5. ✅ 第三方 `/api/v1/client/subscribe` 明文订阅通道未受影响

---

## 关联文件速查

### 后端（`/Users/admin/Downloads/test/rear后/`）
- `app/Utils/SubCrypto.php` — AES 加密工具
- `app/Http/Controllers/V1/Client/VeloxController.php` — 加密订阅控制器
- `app/Http/Routes/V1/ClientRoute.php` — 路由注册（user middleware 组内）
- `app/Http/Middleware/User.php` — 鉴权入口
- `app/Services/AuthService.php` — auth_data 解密
- `app/Services/ServerService.php` — 节点查询
- `app/Services/UserService.php` — 可用性判断

### 客户端（`/Users/admin/Downloads/test/lucky/`）
- `lib/core/services/sub_crypto_service.dart` — AES 解密工具
- `lib/data/datasources/remote/velox_sync_datasource.dart` — 加密订阅数据源
- `lib/data/datasources/remote/server_remote_datasource.dart` — 对上层暴露 getServerList（内部走 velox sync）
- `lib/data/repositories/server_repository_impl.dart` — 缓存管理
- `lib/core/network/api_client.dart` — Dio 客户端 + 调试代理开关
- `lib/core/constants/api_constants.dart` — 端点常量
- `lib/di/injection.dart` — DI 注册
- `packages/singbox_flutter/lib/src/mihomo_service.dart` — mihomo 启动
- `packages/singbox_flutter/lib/src/mihomo_config_generator.dart` — 本地 YAML 生成
- `lib/presentation/blocs/vpn/vpn_bloc.dart` — 连接流程编排
