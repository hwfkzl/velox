# Velox 错误码手册(v1.0.7 起)

> 本文档是 Velox 客户端所有用户可见错误码的**唯一权威索引**。
> 代码定义:`lib/core/errors/error_code.dart`
> 分配纪律:**只增不改**,废弃标 `@Deprecated`,code 值永不复用。
> 维护人:客户端组 + 客服组共同签字,发版前双人 review。
> 生效版本:v1.0.7(此前版本抛出的是无前缀数字或裸 Exception,不在本手册覆盖范围)。

---

## 目录

- [1. 设计原则](#1-设计原则)
- [2. 号段规划总表](#2-号段规划总表)
- [3. 完整 40 个码值表](#3-完整-40-个码值表)
- [4. 分配纪律](#4-分配纪律)
- [5. 客服反查表(症状 → 码)](#5-客服反查表症状--码)
- [6. 隐私红线](#6-隐私红线)
- [7. CI 卡点建议](#7-ci-卡点建议)
- [8. 版本变更记录](#8-版本变更记录)

---

## 1. 设计原则

Velox 的错误码遵循以下几条硬性原则,任何新码分配都必须先自检是否满足:

### 1.1 用户可见 ≠ 用户可读

错误码本身是给**客服/工程师**反查用的,不是给终端用户看的。终端用户看到的是文案(i18n 后的多语言提示),错误码只作为**辅助定位号**放在提示末尾的括号里,例如:

```
网络连接超时,请稍后重试 (VX-1001)
```

因此:

- 码本身是 **ASCII 常量**,不 i18n,不翻译。
- 码不出现在用户主视野里,只在角落,便于客服要求用户"念出括号里那串字母数字"。
- 文案随语言变化,码永远不变。文案可以随版本改,码值一旦发布就冻结。

### 1.2 前缀 `VX-` 的含义

- `VX` = **V**elox e**X**ception,区别于服务端 V2Board 的错误码(通常是纯数字或 `V2B-` 前缀)。
- 有前缀便于客服在混杂日志里一眼分辨这是客户端抛的还是服务端抛的。
- 前缀不占用号段,号段规划从四位数字开始看。

### 1.3 四位数字号段的组织逻辑

- **千位**决定大类(网络/HTTP/认证/订阅/Native/客户端状态/兜底)。
- **百位**在千位大类下切子类(例如 `VX-31xx` 是"认证"大类里的"注册"子类)。
- **十位与个位**是子类下的具体码。
- 号段之间**留白**:每个百位段最多规划 10~20 个具体码,其余空段留给未来扩展。**永远不要把某个百位段填满**,否则再有新错误就没地方塞。

### 1.4 一个错误 = 一个码,不复用

- 不允许"用户名错误"和"密码错误"共用一个码,即便前端 UI 出于安全考虑对外文案一致。日志里必须能区分。
- 同一逻辑分支上的可恢复失败(如"验证码过期"和"验证码错误")分配相邻但不同的码,便于统计。
- 反例:早期版本把所有 4xx HTTP 都拍成一个 code 抛出,导致客服拿到日志无法区分是被封号还是参数错。v1.0.7 修正此问题,拆成 VX-2001 ~ VX-2005 五个独立码。

### 1.5 错误分级

每个码在实现层带一个隐式的严重等级(不写在文案里,只在日志/上报时用):

| 等级 | 含义 | 处理建议 |
| ---- | ---- | -------- |
| INFO | 预期内的用户输入错误(如密码错、验证码错) | 只 toast,不上报 |
| WARN | 环境/暂时性错误(如超时、限流) | toast + 上报采样 10% |
| ERROR | 逻辑错误或后端错误 | toast + 上报 100% |
| FATAL | 客户端崩溃前的兜底码 | 全量上报 + 触发 Sentry |

具体等级见第 3 节码值表最右列(本手册版本先不列,由代码常量 `severity` 字段承载,避免文档与代码双维护)。

### 1.6 错误码文案与 errorKey 的关系

- **码**(如 `VX-1001`):固定 ASCII,永不变。
- **errorKey**(如 `network.timeout`):代码内的稳定字符串标识符,给 i18n arb 文件用来取多语言文案。
- **中文文案**(如"网络连接超时"):由 arb 文件按 errorKey 查表得来,随语言变化。

三者关系:**一对一对一**。改一个必须联动改另两个,否则 CI 卡点会挡住 PR(见第 7 节)。

---

## 2. 号段规划总表

| 号段 | 大类 | 子类切分 | 已用 | 预留 | 触发层 |
| ---- | ---- | -------- | ---- | ---- | ------ |
| `VX-10xx` | 网络层 | 传输层错误(超时/DNS/TLS/连接拒绝) | 4 | 96 | Dio interceptor + Socket |
| `VX-20xx` | HTTP 层 | HTTP 状态码语义化(400/401/403/429/5xx) | 5 | 95 | Dio response interceptor |
| `VX-30xx` | 认证 | 登录/Token 相关 | 5 | 95 | AuthBloc + AuthRepository |
| `VX-31xx` | 认证-注册 | 注册流程专属 | 4 | 96 | RegisterBloc |
| `VX-32xx` | 认证-验证码 | 邮箱/短信验证码 | 3 | 97 | VerifyCodeBloc |
| `VX-40xx` | 订阅 | 订阅信息拉取/解析 | 4 | 96 | SubscriptionRepository |
| `VX-41xx` | 支付 | 下单/支付回调 | 5 | 95 | PaymentBloc |
| `VX-50xx` | Native VPN | VPN 隧道启动/停止/权限 | 5 | 95 | MethodChannel + Native 层 |
| `VX-60xx` | 客户端状态 | 版本/存储/配置一致性 | 3 | 97 | App bootstrap + Update service |
| `VX-90xx` | 未知兜底 | 无法归类的错误 | 2 | 98 | 全局 ErrorHandler |

**说明**:

- **未列出的号段(VX-11xx ~ VX-19xx / VX-21xx ~ VX-29xx / 等等)**目前全部预留,新增子类时优先占用相邻的低位百位段。
- **VX-70xx / VX-80xx** 全段预留,不做任何分配,给未来跨端(Web/桌面独立)或新业务(计费之外的会员权益)预留空间。
- **VX-00xx** 段禁止使用,`0000` 用于测试 fixture,防止把测试码泄漏到生产。

---

## 3. 完整 40 个码值表

> 表格约定:
>
> - "触发条件"描述具体在什么代码路径下抛出。
> - "客服话术"是当用户读出该码时,客服应回复的**第一句话**,后续引导按话术库走。
> - "升级到工程条件"是客服自查完毕仍无法解决时,升级到工程组的判定标准。

### 3.1 VX-10xx 网络层(4)

| 码 | errorKey | 中文文案 | 触发条件 | 客服话术 | 升级到工程条件 |
| --- | --- | --- | --- | --- | --- |
| VX-1001 | `network.timeout` | 网络连接超时,请稍后重试 | Dio `connectTimeout` 或 `receiveTimeout` 触发;或原生 `SocketException: timeout` | "请切换到 4G/5G 试一次,或者换个 Wi-Fi;还不行请把手机重启后再试。" | 用户已换网络 + 重启后仍连续 3 次报同码,收集 host hash + 时间。 |
| VX-1002 | `network.dns.fail` | 域名解析失败,请检查 DNS 或切换网络 | `SocketException: Failed host lookup` 或 iOS `NSURLErrorDNSLookupFailed` | "请打开手机设置 → Wi-Fi → 修改 DNS 为 `1.1.1.1`,再试。" | 用户已换 DNS + 换网络仍报,或多个用户同一时段集中报同一 host。 |
| VX-1003 | `network.tls.handshake` | 安全连接建立失败,请检查系统时间 | `HandshakeException` / `TlsException`;通常是系统时间不对或证书链问题 | "请打开手机设置 → 日期与时间 → 打开'自动设置',再试。" | 系统时间正确 + 系统日期正确后仍复现,可能是证书被中间人拦截,升级工程排查。 |
| VX-1004 | `network.connection.refused` | 无法连接到服务器,请稍后重试 | `SocketException: Connection refused` 或 `ClientClosedRequest` | "请稍等 5 分钟后再试;如仍报错请退出 App 完全后台清理后重开。" | 连续 5 分钟以上仍报同码,且用户网络其他 App 正常,可能是入口 IP 被封禁,升级运维。 |

### 3.2 VX-20xx HTTP 层(5)

| 码 | errorKey | 中文文案 | 触发条件 | 客服话术 | 升级到工程条件 |
| --- | --- | --- | --- | --- | --- |
| VX-2001 | `http.bad_request` | 请求参数错误,请更新到最新版本 | 收到 HTTP 400 且响应体不带业务 code | "请到官网下载最新版本安装(不用卸载,直接覆盖)。" | 用户确认已升到最新版仍报,升级客户端组核对协议。 |
| VX-2002 | `http.forbidden` | 访问被拒绝,请联系客服 | HTTP 403 且响应体不携带账号状态字段 | "请提供您的注册邮箱,客服代查是否有账号异常。" | 已核对账号状态正常,升级后端确认接口 ACL 策略。 |
| VX-2003 | `http.rate_limit` | 请求过于频繁,请稍后再试 | HTTP 429 或响应体带 `Retry-After` | "请等 60 秒后再试;若长时间无法恢复,请截图给客服。" | 单账号 24h 内累计触发 > 5 次,升级安全组分析是否为异常调用。 |
| VX-2004 | `http.server.5xx` | 服务器暂时不可用,请稍后重试 | HTTP 5xx 响应 | "服务器正在维护/抢救中,请稍等 10 分钟后再试。" | 用户提供的时间落在无维护公告窗口 + 影响面广(多个客服反馈),升级 SRE。 |
| VX-2005 | `http.malformed_response` | 服务器响应异常,请更新版本 | 收到成功状态码但 body 无法解析(非 JSON / 缺关键字段) | "请到官网下载最新版本安装。" | 确认已最新版仍报,提供 host hash + 时间给客户端组抓包。 |

### 3.3 VX-30xx 认证(5)

| 码 | errorKey | 中文文案 | 触发条件 | 客服话术 | 升级到工程条件 |
| --- | --- | --- | --- | --- | --- |
| VX-3001 | `auth.wrong_credentials` | 邮箱或密码错误 | POST `/passport/auth/login` 返回业务错误"password_error" | "请点击'忘记密码'重设一次。" | 用户确认密码正确,且已重置密码仍报,升级后端查账号哈希。 |
| VX-3002 | `auth.account_locked` | 账号已被封禁,请联系客服 | 登录返回 `account_locked` 或 `banned` | "请提供注册邮箱,客服核实账号状态。" | 账号状态确为正常但客户端仍报此码,升级后端。 |
| VX-3003 | `auth.token.expired` | 登录已过期,请重新登录 | 拿旧 token 请求任意接口,后端返回 401 且 header 带 `X-Token-Expired: 1` | "请退出登录再重新登录一次。" | 用户新登录后 5 分钟内又报同码,升级客户端组查 token 刷新逻辑。 |
| VX-3004 | `auth.token.missing` | 登录状态丢失,请重新登录 | 本地 SecureStorage 读取不到 token 但业务流程要求已登录 | "请重新登录一次。" | 用户明确未主动退出但反复报,可能是 iOS Keychain 权限异常,升级客户端组。 |
| VX-3005 | `auth.session.conflict` | 账号在其他设备登录,请重新登录 | 后端返回 `session_kicked` 或多端登录冲突 | "请确认没有他人登录您的账号;若确定只您本人,请修改密码。" | 用户改密码后仍频繁被踢,可能是账号泄漏,升级安全组。 |

### 3.4 VX-31xx 注册(4)

| 码 | errorKey | 中文文案 | 触发条件 | 客服话术 | 升级到工程条件 |
| --- | --- | --- | --- | --- | --- |
| VX-3101 | `register.email.duplicate` | 该邮箱已注册,请直接登录 | 注册接口返回 `email_exists` | "请点击'登录'并使用该邮箱登录;忘记密码可点'忘记密码'。" | 用户坚称从未注册,提供邮箱给客服代查是否被他人抢注。 |
| VX-3102 | `register.email.invalid` | 邮箱格式不正确 | 客户端本地正则或后端 `email_invalid` | "请检查邮箱是否有多余空格/中文字符/缺少 @。" | 已确认邮箱标准且业界通用后缀仍报错,升级客户端组查正则。 |
| VX-3103 | `register.password.weak` | 密码强度不足,请使用 8 位以上包含字母数字 | 密码不符合前端 / 后端强度策略 | "请设置 8 位以上,同时包含字母和数字。" | 用户提供的密码明显达标仍被拒,升级客户端组核对策略同步。 |
| VX-3104 | `register.invite.invalid` | 邀请码无效或已失效 | 后端 `invite_code_invalid` / `invite_code_expired` | "请核对邀请码;若从群里复制,可能带了空格或看不见字符,请手动输入。" | 用户确认从官方渠道获取邀请码仍无效,升级运营组查渠道。 |

### 3.5 VX-32xx 验证码(3)

| 码 | errorKey | 中文文案 | 触发条件 | 客服话术 | 升级到工程条件 |
| --- | --- | --- | --- | --- | --- |
| VX-3201 | `verify.code.wrong` | 验证码错误 | 后端 `verify_code_wrong` | "请核对邮件中的最新一封验证码(以最新一封为准)。" | 用户已用最新一封仍错,可能是邮件被延迟或代填/被前置抓包,升级后端查生成日志。 |
| VX-3202 | `verify.code.expired` | 验证码已过期,请重新获取 | 后端 `verify_code_expired` | "请点击'重新获取'并在 5 分钟内输入。" | 用户 30 秒内就报过期,升级后端查 TTL 配置。 |
| VX-3203 | `verify.code.send_limit` | 发送过于频繁,请稍后再试 | 60 秒内重复请求发送验证码 | "请等待 60 秒后再点击'获取验证码'。" | 用户等足 60 秒仍限流,或多用户在同一分钟内集中报此码,升级邮件/短信服务商。 |

### 3.6 VX-40xx 订阅(4)

| 码 | errorKey | 中文文案 | 触发条件 | 客服话术 | 升级到工程条件 |
| --- | --- | --- | --- | --- | --- |
| VX-4001 | `subscription.fetch.fail` | 获取订阅信息失败 | 拉取 `/user/getSubscribe` 网络成功但业务失败 | "请到'我的' → '刷新',或退出重新登录。" | 用户已刷新 + 重登仍报,升级后端。 |
| VX-4002 | `subscription.parse.fail` | 订阅信息解析失败,请更新版本 | 订阅 URL 返回内容无法解析成节点列表(base64 / clash yaml / velox json 都失败) | "请到官网下载最新版本安装。" | 确认已最新版仍报,提供 host hash + 时间给客户端组抓包。 |
| VX-4003 | `subscription.expired` | 订阅已到期,请续费 | 后端返回 `expired_at` 早于当前时间 | "请到'我的'→'续费'完成续订。" | 用户确认已支付但仍显示到期,给客服工单查支付流水。 |
| VX-4004 | `subscription.traffic.exhausted` | 流量已用尽,请等待重置或升级套餐 | 后端返回 `u+d >= transfer_enable` | "您当月流量已用完,可到'我的'查看下次重置时间或升级到更高档套餐。" | 用户实际使用远低于套餐流量仍显示用尽,可能后端计费异常,升级后端。 |

### 3.7 VX-41xx 支付(5)

| 码 | errorKey | 中文文案 | 触发条件 | 客服话术 | 升级到工程条件 |
| --- | --- | --- | --- | --- | --- |
| VX-4101 | `payment.order.create.fail` | 下单失败,请稍后重试 | POST `/user/order/save` 返回业务失败 | "请稍等 1 分钟后重新下单;如反复失败请截图给客服。" | 用户尝试 3 次以上仍下单失败,升级后端查商品配置。 |
| VX-4102 | `payment.channel.unavailable` | 当前支付方式不可用,请选其他方式 | 支付渠道返回 `channel_disabled` 或客户端未获取到可用渠道列表 | "请在下单页更换其他支付方式(如 USDT / 支付宝 / PayPal)。" | 所有渠道都不可用,升级运营组查商户号配置。 |
| VX-4103 | `payment.gateway.timeout` | 支付网关无响应,请稍后查询订单 | 唤起第三方支付后 5 分钟无回调 | "请到'我的' → '订单'查看订单状态;若已扣款但订单显示未支付,请截图付款凭证给客服。" | 用户提供扣款凭证 + 订单号,客服工单转财务对账。 |
| VX-4104 | `payment.callback.mismatch` | 订单状态异常,请联系客服 | 支付回调金额与订单不符,或订单号不存在 | "请提供订单号 + 付款截图给客服人工处理。" | 必升级:此码本身就是要求人工核对。 |
| VX-4105 | `payment.user.cancelled` | 支付已取消 | 用户主动关闭第三方支付页 | "如需重新支付,请回到订单页点击'继续支付'。" | 一般不升级;若用户明确未取消却报此码,升级客户端组查支付 SDK 回调。 |

### 3.8 VX-50xx Native VPN(5)

| 码 | errorKey | 中文文案 | 触发条件 | 客服话术 | 升级到工程条件 |
| --- | --- | --- | --- | --- | --- |
| VX-5001 | `native.vpn.permission.denied` | 未授权 VPN 权限,请在系统设置中允许 | Android `VpnService.prepare` 返回 null 之外的 Intent 但用户拒绝;iOS `NEVPNManager.saveToPreferences` 返回权限错误 | "请打开手机设置 → VPN,允许 Velox 建立 VPN 连接;或卸载重装 App 触发权限弹窗。" | 用户已授权 + 卸载重装后仍报,升级客户端组查 native 代码。 |
| VX-5002 | `native.vpn.start.fail` | VPN 启动失败,请重启 App 后重试 | Native 层 `startVpn` 返回失败(mihomo / sing-box 返回非零) | "请退出 App 完全后台清理,再重新打开并连接。" | 重启 App 后仍复现,收集 native error code(见"隐私红线"允许上报清单)。 |
| VX-5003 | `native.vpn.tunnel.lost` | VPN 连接已断开,请重新连接 | 已连接状态下 tunnel 意外断开(网络切换 / 系统 kill) | "请点击'断开'再'连接'一次;若频繁断开可开启'自动重连'。" | 单会话内 10 分钟断超过 3 次,收集断开时间 + native code。 |
| VX-5004 | `native.config.invalid` | 节点配置错误,请刷新订阅 | Native 层解析节点配置失败(端口/协议/密钥字段缺失) | "请到'节点列表' → 下拉刷新;或退出重新登录。" | 已刷新 + 重登仍报,可能节点侧下发配置错,升级运维。 |
| VX-5005 | `native.system.always_on` | 系统"始终开启 VPN"启用中,请关闭后再操作 | Android 检测到系统 Always-On VPN 且不是 Velox | "请打开手机设置 → VPN,关闭'始终开启 VPN'或将 Velox 设为默认。" | 一般不升级;若用户操作后仍报,升级客户端组核对判定。 |

### 3.9 VX-60xx 客户端状态(3)

| 码 | errorKey | 中文文案 | 触发条件 | 客服话术 | 升级到工程条件 |
| --- | --- | --- | --- | --- | --- |
| VX-6001 | `client.version.too_old` | 版本过低,请升级到最新版本 | 后端在任意接口返回 `min_version_required` 大于当前版本 | "请到官网下载最新版本(直接覆盖安装即可)。" | 用户装的确实是最新版仍报,升级客户端组核对版本号 build。 |
| VX-6002 | `client.storage.corrupt` | 本地数据异常,建议清除缓存 | Hive / SecureStorage 读写抛异常 | "请到'我的' → '关于' → '清除缓存';或卸载重装(会丢登录状态需重新登录)。" | 用户清缓存 + 重装后仍报,升级客户端组。 |
| VX-6003 | `client.config.mismatch` | 客户端配置版本不匹配,请重启 App | `/velox/config.json` 拉到但版本号低于本地要求的最低版 | "请退出 App 后重新打开;仍无效请卸载重装。" | 重装后仍报,升级客户端组核对 OSS 配置发布。 |

### 3.10 VX-90xx 未知兜底(2)

| 码 | errorKey | 中文文案 | 触发条件 | 客服话术 | 升级到工程条件 |
| --- | --- | --- | --- | --- | --- |
| VX-9001 | `unknown.uncaught` | 未知错误,请截图联系客服 | 全局 `FlutterError.onError` 兜底 / `PlatformDispatcher.instance.onError` 兜底 | "请截图当前页面 + 报错弹窗,发给客服;并告知您在做什么操作时报错。" | 必升级:此码等价于崩溃前一秒。 |
| VX-9002 | `unknown.assertion` | 客户端内部检查失败,请重启 App | Dart `assert` 失败或不变量校验(如 State 机异常) | "请退出 App 完全后台清理,再重新打开;若必现请截图给客服。" | 必升级 + 抓取上下文(见"隐私红线"允许上报清单)。 |

---

## 4. 分配纪律

### 4.1 只增不改

**已发布的码值永久冻结**,禁止:

- 更改一个已发布码的 errorKey。
- 更改一个已发布码的号段归属。
- 复用一个已废弃码的数字给新错误。

原因:

1. 客服话术库以码为主键;改码会导致话术错配。
2. 用户截图/日志里的老码会永远存在,改了就断连。
3. 上报后端的统计指标以码为分组;改了就断了历史趋势曲线。

### 4.2 废弃流程

若某个错误在业务演进中确实不再出现,不是删除,是"废弃":

1. 在 `error_code.dart` 中给该常量加 `@Deprecated('原因说明,替代码 VX-xxxx')` 注解。
2. 在本手册对应行前追加 `~~` 删除线 + 备注"(v1.0.x 起废弃,替代:VX-xxxx)"。
3. **保留 code 值,不释放**。任何后续新错误禁止使用该数字。
4. 客服话术库标记为"历史码",遇到用户仍念出可继续处理。

反例:v1.0.5 曾把 `login_captcha_wrong` 直接删除,v1.0.6 上线后新的"图形验证码错误"复用了同一 code,导致老版本用户仍在报旧语义但客服话术已切换成新语义,产生 30+ 单误伤。之后建立本纪律。

### 4.3 新增走 PR

新码分配的完整流程:

1. **在 Issue 里立项**:说明触发场景 + 与现有码的区别(为什么不能复用现有码)。
2. **确认号段**:从"号段规划总表"中挑一个合适百位段;在段内挑一个未占用的具体数字(注意留白纪律)。
3. **提 PR**:同一 PR 内必须包含:
   - `error_code.dart` 中新增常量(带 `///` doc comment 描述触发条件)。
   - `intl_zh.arb` / `intl_zh_TW.arb` / `intl_en.arb` 三个 arb 文件同步加 errorKey 对应文案。
   - **本手册**对应号段小节新增一行。
   - 一个抛出该码的单元测试(至少覆盖一条路径)。
4. **评审**:至少一位客户端组 + 一位客服组签字。客服组主要审"客服话术"和"升级到工程条件"两列。
5. **CI 卡点**:见第 7 节,四项(常量/arb/文档/测试)缺一即 build fail。

### 4.4 不允许的操作

除"改"以外,以下也禁止:

- 在 `error_code.dart` 定义了常量但没在 arb 文件加文案 —— i18n 会 fallback 到 errorKey 原文,用户看到英文 dot 号感极差。
- 在 arb 加了文案但没在本手册记录 —— 客服反查断链。
- 直接在业务代码里 `throw 'VX-xxxx: ...'` 硬编码字符串 —— 必须走 `AppException(code: ErrorCode.xxx)` 类型化构造。
- 一个 PR 内批量占用多个码(例如"我先占 5001~5010") —— 每个码必须有对应的实际使用点。

---

## 5. 客服反查表(症状 → 码)

用户描述往往不含码值,或用户念不清括号里的字符。本表按**用户可能的说法**归类,反查最可能的候选码。

### 5.1 网络类症状

| 用户说法 | 最可能候选 | 次可能 |
| -------- | ---------- | ------ |
| "转圈很久没反应""半天没登进去" | VX-1001 | VX-1004 |
| "说找不到服务器""域名什么什么错" | VX-1002 | VX-1004 |
| "安全连接""证书""时间不对" | VX-1003 | - |
| "怎么都连不上""刚才还好好的" | VX-1004 | VX-1001 |
| "太频繁""限制访问" | VX-2003 | - |
| "服务器错误""500""维护中" | VX-2004 | - |

### 5.2 登录/注册类症状

| 用户说法 | 最可能候选 | 次可能 |
| -------- | ---------- | ------ |
| "登录不上""密码不对" | VX-3001 | - |
| "账号被封了""被封禁" | VX-3002 | - |
| "提示重新登录""登录过期" | VX-3003 | VX-3004 |
| "打开就要我登录,明明登过" | VX-3004 | VX-3003 |
| "被踢了""别的设备" | VX-3005 | - |
| "邮箱已注册但我没注册过" | VX-3101 | - |
| "邮箱说不对但我看着没错" | VX-3102 | - |
| "密码太弱" | VX-3103 | - |
| "邀请码不对" | VX-3104 | - |

### 5.3 验证码类症状

| 用户说法 | 最可能候选 | 次可能 |
| -------- | ---------- | ------ |
| "验证码错" | VX-3201 | VX-3202 |
| "过期了""要重新发" | VX-3202 | - |
| "点了没反应""说太频繁" | VX-3203 | - |

### 5.4 订阅/支付类症状

| 用户说法 | 最可能候选 | 次可能 |
| -------- | ---------- | ------ |
| "没有节点""节点是空的""刷不出来" | VX-4001 | VX-4002 |
| "订阅到期""不能用了" | VX-4003 | - |
| "流量没了""流量用完" | VX-4004 | - |
| "买不了""付不了""下单不了" | VX-4101 | VX-4102 |
| "支付方式选不了" | VX-4102 | - |
| "付了钱但没到账" | VX-4103 | VX-4104 |
| "扣款成功但订单是未支付" | VX-4104 | VX-4103 |
| "支付取消了" | VX-4105 | - |

### 5.5 VPN/连接类症状

| 用户说法 | 最可能候选 | 次可能 |
| -------- | ---------- | ------ |
| "连不上""连了没反应" | VX-5002 | VX-5001 |
| "系统弹了个框,没允许" | VX-5001 | - |
| "老是掉线""断断续续" | VX-5003 | - |
| "节点配置错""节点异常" | VX-5004 | - |
| "系统 VPN 冲突""始终开启 VPN" | VX-5005 | - |

### 5.6 其他

| 用户说法 | 最可能候选 | 次可能 |
| -------- | ---------- | ------ |
| "让我升级""版本太低" | VX-6001 | - |
| "打开就闪退""数据坏了" | VX-6002 | VX-9002 |
| "报了个不认识的错" | VX-9001 | VX-9002 |

**使用方式**:客服先按上表定位 2~3 个候选码,再让用户念出括号里字符验证。若用户念的码不在候选内,回本手册第 3 节的详细表按 code 反查触发条件,判断是否可能是描述偏差。

---

## 6. 隐私红线

错误上报是必要的(否则工程组无从复现),但上报内容必须遵守以下红线:

### 6.1 禁止上报清单

以下内容**永远禁止**出现在错误上报的 payload 里(无论明文/加密/hash):

- 用户 token(access token / refresh token / 任何登录凭证)。
- 用户密码(即使已 hash)。
- 完整订阅 URL(URL 里通常带 token 参数)。
- 节点服务器 IP / 域名。
- 用户当前公网 IP。
- 用户邮箱(注册邮箱 = 账号,PII)。
- 用户手机号。
- 支付订单里的银行卡/账户信息。
- 系统日志中包含以上内容的原始行。

### 6.2 允许上报清单

上报时可以带的字段:

- **错误码**(`VX-xxxx`)—— 本手册的核心目的。
- **errorKey**(如 `network.timeout`)—— 便于机器聚合。
- **触发时间**(UTC 秒级时间戳)。
- **App 版本** + **build 号**(用于版本回归定位)。
- **平台**(android/ios/macos/windows)+ **系统版本号**(如 `Android 14` / `iOS 17.5`)。
- **native 错误码**(mihomo / sing-box 层的错误 code,已在 native 层脱敏,不含 IP)。
- **host hash**:若必须上报某个 host 是否可达,使用 `sha256(host).substring(0,8)`,永远不上报明文 host。
- **is_wifi / is_cellular** 网络类型标记(不含 SSID / 运营商名)。
- **UI 路径**(如 `login_page → verify_code_input` 这种 route 名链,不含用户输入内容)。

### 6.3 灰色地带处理

某些字段有争议,统一裁决:

| 字段 | 是否允许 | 理由 |
| ---- | -------- | ---- |
| 设备型号(如 `iPhone14,3`) | 允许 | 无用户可识别性,故障排查有用。 |
| 设备唯一 ID(IDFV / Android ID) | **禁止** | 属 PII 范畴,不允许出现在客户端上报的 error payload。 |
| 用户 UID(V2Board 内部 user_id) | **禁止** | 会话追踪由后端日志承担,客户端上报不带。 |
| Wi-Fi SSID / BSSID | **禁止** | 定位属性,PII。 |
| 运营商名称(如"中国移动") | 允许 | 群体统计,非个体识别。 |
| 系统语言 / 时区 | 允许 | 非 PII,故障相关(有些 crash 与时区有关)。 |

### 6.4 校验方式

- 上报模块内置一个 **hard denylist**,匹配到 `token=` / `Bearer ` / IP 正则 / 邮箱正则 / 手机号正则时,直接丢弃整条上报并本地告警。
- CI 阶段 grep 检查:`error_code.dart` 及上报模块禁止出现任何 URL 拼接或 token 打印代码路径(通过静态扫描规则)。

### 6.5 违规的后果

违反红线是**发版红线**:

- Code review 阶段被发现:PR 直接拒。
- 已上线才发现:立即出补丁版本,并追溯已上报的服务端存储,做数据清除。
- 累犯:该模块负责人取消上报模块的写权限。

---

## 7. CI 卡点建议

为保障"码/errorKey/文案/文档"四位一体,CI 里内置以下卡点。**任一失败即 build fail**,禁止合入:

### 7.1 常量-文档一致性检查

脚本 `tools/check_error_code_docs.dart`:

1. 扫描 `lib/core/errors/error_code.dart`,提取所有 `static const ErrorCode` 常量(带非 `@Deprecated` 标记)。
2. 扫描本文件(`docs/error-codes/README.md`),提取"### 3.x"下所有表格首列的 `VX-xxxx`。
3. 对比两个集合:
   - 代码里有,文档没有 → `build fail`,提示"新增了 VX-xxxx 但未更新 docs/error-codes/README.md"。
   - 文档有,代码没有 → `build fail`,提示"文档里的 VX-xxxx 在代码中不存在,请核对"。

### 7.2 errorKey-arb 同步检查

脚本 `tools/check_error_key_i18n.dart`:

1. 提取 `error_code.dart` 中每个常量的 `errorKey` 字段。
2. 检查三个 arb 文件(`intl_zh.arb` / `intl_zh_TW.arb` / `intl_en.arb`)是否都有对应 key。
3. 缺一即 `build fail`,提示具体缺哪个语言 + 哪个 key。

### 7.3 号段合法性检查

脚本 `tools/check_error_code_range.dart`:

1. 每个 `VX-xxxx` 常量的数字部分必须落在本手册"号段规划总表"的已定义大类内。
2. 若代码里出现 `VX-70xx` / `VX-80xx` 这类预留段的常量,`build fail`。
3. 若代码里出现 `VX-00xx` 段的非测试常量,`build fail`(测试 fixture 需带 `@visibleForTesting` 标记)。

### 7.4 硬编码检查

静态扫描:

1. 全项目 grep `throw '.*VX-` 命中即 `build fail` —— 禁止硬编码字符串抛错,必须走 `AppException(code: ErrorCode.xxx)`。
2. 全项目 grep `print(.*VX-` 命中即 `build fail` —— 禁止 print 带错误码,应走 logger。

### 7.5 隐私红线扫描

静态扫描上报模块 `lib/core/telemetry/error_reporter.dart`:

1. 上报 payload 构造函数的参数列表不允许出现 `token` / `password` / `url` / `email` / `phone` / `ip` 等敏感字段名。
2. 若必须上报某个字段的哈希,函数名必须以 `Hashed` / `Digest` 结尾,便于评审识别。

### 7.6 废弃标记完整性检查

若某常量被 `@Deprecated` 标记:

1. `deprecation` 消息必须包含替代码值(如"replaced by VX-30xx 段内的某个新码")。
2. 本手册对应行必须有删除线标记 + 备注,否则 CI fail。

### 7.7 建议的 CI 配置片段

```yaml
# .github/workflows/error_code_check.yml
name: error-code-check
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - name: constant-doc consistency
        run: dart run tools/check_error_code_docs.dart
      - name: errorKey-arb sync
        run: dart run tools/check_error_key_i18n.dart
      - name: range legality
        run: dart run tools/check_error_code_range.dart
      - name: hardcoded string
        run: |
          if grep -R --include="*.dart" -E "throw '.*VX-" lib/; then
            echo "hardcoded VX- string in throw, forbidden"; exit 1
          fi
      - name: privacy scan
        run: dart run tools/check_error_reporter_privacy.dart
```

上述脚本工程组另立仓完成实现,本手册只给规范。

---

## 8. 版本变更记录

| 版本 | 日期 | 变更 | 变更人 |
| ---- | ---- | ---- | ------ |
| v1.0.7 | 2026-07-初次发布 | 建立错误码体系,分配 40 个初始码 | 客户端组 + 客服组 |
| - | - | - | - |

**未来变更**:

- 每次发版若涉及错误码增删,在此表增加一行。
- 变更须包含:新增哪些码 / 废弃哪些码 / 调整哪些文案(errorKey/中文文案的措辞可微调,严格来说不算"改"但仍需记录)。

---

## 附录 A. 快速索引

按码值排序的所有 40 个码:

- **网络**:VX-1001 / VX-1002 / VX-1003 / VX-1004
- **HTTP**:VX-2001 / VX-2002 / VX-2003 / VX-2004 / VX-2005
- **认证**:VX-3001 / VX-3002 / VX-3003 / VX-3004 / VX-3005
- **注册**:VX-3101 / VX-3102 / VX-3103 / VX-3104
- **验证码**:VX-3201 / VX-3202 / VX-3203
- **订阅**:VX-4001 / VX-4002 / VX-4003 / VX-4004
- **支付**:VX-4101 / VX-4102 / VX-4103 / VX-4104 / VX-4105
- **Native VPN**:VX-5001 / VX-5002 / VX-5003 / VX-5004 / VX-5005
- **客户端状态**:VX-6001 / VX-6002 / VX-6003
- **未知兜底**:VX-9001 / VX-9002

合计:40 个。

## 附录 B. 相关文档

- `lib/core/errors/error_code.dart` —— 码常量定义。
- `lib/core/errors/app_exception.dart` —— 抛出类型化异常的入口。
- `lib/core/telemetry/error_reporter.dart` —— 错误上报模块(遵守第 6 节隐私红线)。
- `lib/l10n/intl_zh.arb` / `intl_zh_TW.arb` / `intl_en.arb` —— i18n 文案表。
- `docs/PRD.md` —— 产品需求文档,错误处理需求见 §4.7。
- `docs/VELOX_DESIGN_SPEC.md` —— 客户端设计规范,错误分层设计见 §6。
- `tools/check_error_code_docs.dart` —— 常量-文档一致性 CI 脚本。

## 附录 C. 抛出示例(代码规范)

以下是每个大类的规范抛出示例,供开发实现时对照。

### C.1 网络层抛出

```dart
// lib/core/network/dio_client.dart
Future<Response<T>> _request<T>(RequestOptions options) async {
  try {
    return await _dio.fetch<T>(options);
  } on DioException catch (e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        throw AppException(code: ErrorCode.networkTimeout);
      case DioExceptionType.connectionError:
        if (e.error is SocketException) {
          final se = e.error as SocketException;
          if (se.osError?.errorCode == 8 /* ENOENT/DNS */) {
            throw AppException(code: ErrorCode.networkDnsFail);
          }
          throw AppException(code: ErrorCode.networkConnectionRefused);
        }
        throw AppException(code: ErrorCode.networkConnectionRefused);
      case DioExceptionType.badCertificate:
        throw AppException(code: ErrorCode.networkTlsHandshake);
      default:
        throw AppException(code: ErrorCode.unknownUncaught, cause: e);
    }
  }
}
```

### C.2 HTTP 层抛出

```dart
// lib/core/network/response_interceptor.dart
void onResponse(Response resp, ResponseInterceptorHandler handler) {
  final code = resp.statusCode ?? 0;
  if (code >= 200 && code < 300) return handler.next(resp);
  if (code == 400) throw AppException(code: ErrorCode.httpBadRequest);
  if (code == 403) throw AppException(code: ErrorCode.httpForbidden);
  if (code == 429) throw AppException(code: ErrorCode.httpRateLimit);
  if (code >= 500) throw AppException(code: ErrorCode.httpServer5xx);
  // 401 由业务侧根据接口上下文决定抛哪个码,不在此拦截统一处理。
  throw AppException(code: ErrorCode.httpBadRequest);
}
```

注意:401 故意不在这里统一,因为不同接口下 401 有不同语义(见 FAQ Q3)。

### C.3 认证层抛出

```dart
// lib/data/repositories/auth_repository_impl.dart
Future<User> login(String email, String password) async {
  final resp = await _dio.post('/passport/auth/login',
      data: {'email': email, 'password': password});
  final body = resp.data as Map<String, dynamic>;
  if (body['status'] == 'fail') {
    final msg = body['message'] as String? ?? '';
    if (msg.contains('password')) {
      throw AppException(code: ErrorCode.authWrongCredentials);
    }
    if (msg.contains('locked') || msg.contains('banned')) {
      throw AppException(code: ErrorCode.authAccountLocked);
    }
    throw AppException(code: ErrorCode.unknownUncaught);
  }
  return User.fromJson(body['data']);
}
```

### C.4 Native 层抛出(MethodChannel)

```dart
// lib/core/native/vpn_channel.dart
Future<void> startTunnel(String configJson) async {
  try {
    await _channel.invokeMethod('startVpn', {'config': configJson});
  } on PlatformException catch (e) {
    switch (e.code) {
      case 'PERMISSION_DENIED':
        throw AppException(code: ErrorCode.nativeVpnPermissionDenied);
      case 'ALWAYS_ON_CONFLICT':
        throw AppException(code: ErrorCode.nativeSystemAlwaysOn);
      case 'CONFIG_PARSE_FAIL':
        throw AppException(code: ErrorCode.nativeConfigInvalid);
      default:
        throw AppException(
            code: ErrorCode.nativeVpnStartFail,
            nativeCode: e.code); // 上报时会带 nativeCode(第 6 节允许)
    }
  }
}
```

### C.5 全局兜底

```dart
// lib/main.dart
void main() {
  FlutterError.onError = (details) {
    ErrorReporter.report(AppException(
        code: ErrorCode.unknownUncaught, cause: details.exception));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReporter.report(AppException(
        code: ErrorCode.unknownUncaught, cause: error));
    return true;
  };
  runZonedGuarded(() => runApp(const MyApp()), (error, stack) {
    ErrorReporter.report(AppException(
        code: ErrorCode.unknownUncaught, cause: error));
  });
}
```

三层兜底缺一不可,兜底路径必须是 `unknownUncaught`(VX-9001)。若能明确是 assert 失败,用 `unknownAssertion`(VX-9002)。

## 附录 D. UI 展示规范

错误码在 UI 上的展示细节:

### D.1 显示位置

- **短提示(SnackBar / Toast)**:文案末尾追加 `(VX-xxxx)`,如"网络连接超时,请稍后重试 (VX-1001)"。
- **弹窗(Dialog)**:标题为文案,内容区右下角小字灰色显示 `VX-xxxx`,可点击复制。
- **整页错误(Full-page Error)**:大标题 + 说明 + 底部小字 `VX-xxxx · <build号> · <UTC时间>`。

### D.2 样式约定

- 括号内的 `VX-xxxx` 使用等宽字体(monospace),避免"O/0/l/1"混淆。
- 颜色比正文淡两档(如正文 #000,码 #666)。
- 不加下划线,不做超链接跳转(避免钓鱼)。

### D.3 复制交互

- 点击错误码可复制到剪贴板,复制内容为 `VX-xxxx build=1.0.7+42 time=2026-07-09T10:22:31Z`。
- 复制后 toast 提示"已复制,请粘贴给客服"。
- 长按可展开更多上下文(仅 debug 版本;release 版本不展开,以免用户误传隐私)。

### D.4 无网页错误页

对全局网络中断(所有请求都失败),不要每个请求单独弹 SnackBar,应显示整页 empty state:

- 图标(离线图标) + "网络似乎断开了" + "(VX-1004)" + "重试"按钮。
- 重试按钮触发全局重连,而非仅重试单个请求。

## 附录 E. 与 V2Board 后端错误的映射

V2Board 后端错误通常有以下几种形态,客户端要将其映射到本手册的码值:

### E.1 后端形态

- **纯 HTTP 状态码**(400/401/403/429/500)—— 由响应拦截器映射(见 C.2)。
- **业务响应体**(`{"status":"fail","message":"xxx"}`)—— 由业务代码根据 message 语义映射。
- **业务码**(部分接口带 `code: 12001`)—— 有对照表映射到 VX 码。

### E.2 部分业务码对照(节选)

| V2Board code | 语义 | 映射到 |
| ------------ | ---- | ------ |
| 无 code + message 含 `password` | 密码错误 | VX-3001 |
| 无 code + message 含 `locked` | 账号封禁 | VX-3002 |
| 无 code + message 含 `email exists` | 邮箱已注册 | VX-3101 |
| 无 code + message 含 `verify code error` | 验证码错误 | VX-3201 |
| 无 code + message 含 `verify code expired` | 验证码过期 | VX-3202 |
| 无 code + message 含 `frequency` | 发送过频 | VX-3203 |
| 无 code + message 含 `expired` (订阅) | 订阅到期 | VX-4003 |

后端未来若引入结构化业务码(而非 message 字符串匹配),客户端将改为按 code 直接映射,现有 VX 码不变。这也是"客户端码稳定,后端可自由重构"的收益点。

### E.3 兜底策略

若接口返回失败但无法识别 message / code,统一抛 `VX-9001`(unknownUncaught),而非静默吞掉。宁可用户看到未知错误也不能让错误消失 —— 只有能看到才有机会修复。

## 附录 F. 常见 FAQ

**Q1:客服拿到用户发来的截图,VX-xxxx 括号看不清怎么办?**
A:先用第 5 节的"症状 → 码"反查表根据用户描述给出 2~3 个候选;再让用户长按截图放大或改让用户读出。

**Q2:用户报的码不在本手册里?**
A:分三种情况:
- 老版本客户端(v1.0.6 及以前)可能有裸数字码或无前缀码,请建议用户升级到 v1.0.7+。
- 客户端最新版仍报表外码 —— 走"升级工程"流程,由客户端组核对是否漏更新文档(此时 CI 应已挡住,若挡不住是 CI bug)。
- 用户念错(比如把 `0` 念成 `O`,把 `1` 念成 `L`)—— 客服反复确认。

**Q3:同一个后端错误(比如 401)在不同接口下为什么码不一样?**
A:因为语义不同。`/passport/auth/login` 返回 401 是密码错(VX-3001),`/user/getSubscribe` 返回 401 是 token 过期(VX-3003)。上下文决定语义,而非 HTTP 状态码本身决定语义。

**Q4:能不能给一个码分配两种文案?**
A:不能。一个码对应一个 errorKey,一个 errorKey 对应各语言各一条文案。若同一逻辑场景需要区分文案(例如"你自己触发的"与"别人触发的"),必须分成两个码。

**Q5:预留段(VX-70xx / VX-80xx)什么时候会启用?**
A:等下面某个大类饱和时(单个千位段填过 100 个)才考虑扩展。当前分布远未饱和,预留段不必急于启用。启用需走本手册的 PR + CR 流程正式变更号段规划表。

**Q6:上报后端能不能自动从 arb 反查中文文案?**
A:能。上报只发码,后端展示时按码查最新版的中文文案。这也是"文案可改,码不可改"的实操含义 —— 后端字典即时更新,不影响客户端。

**Q7:为什么不用整数枚举(0/1/2/…)而用 4 位数字?**
A:整数枚举无法承载分类语义,新加错误要么打乱顺序要么塞末尾,可读性差;4 位数字带天然千位/百位分类,客服念起来也顺口(念 4 位与念 2/3 位耗时接近但携带的信息量翻倍)。
