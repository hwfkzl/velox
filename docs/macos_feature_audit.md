# macOS 客户端功能裁剪分析

对照后端 `pkapq.space` (V2Board / Webman) 与 Velox Flutter 客户端 `lucky/`，目的：定位客户端中**后端不支持**或**桌面端体验冗余**的功能，并给出 macOS 端的裁剪建议。

> 扫描范围
> - 后端：`/Users/admin/Downloads/pkapq.space/app/Http/Routes/{V1,V2}` + 对应 `Controllers/V1/{Passport,User,Guest,AppClient,Client}`
> - 客户端：`lucky/lib/app/router.dart`、`lib/presentation/pages/**`、`lib/data/datasources/remote/**`、`lib/core/constants/api_constants.dart`

---

## 1. 后端 vs 客户端 功能对照矩阵

| 功能 | 后端 (pkapq.space) | 客户端 (lucky) | 状态 |
| --- | --- | --- | --- |
| 登录 / 注册 / 忘记密码 / 邮箱验证码 | ✅ `/passport/auth/*` `/passport/comm/sendEmailVerify` | ✅ `auth/login_page.dart` 等 | OK |
| QR 导入 / URL 导入 | — (本地配置) | ✅ `/qr-import` `/url-import` | OK，无后端依赖 |
| 套餐 / 订单 / 优惠券 / 支付 | ✅ `/user/plan/fetch` `/user/order/*` `/user/coupon/check` | ✅ `subscription/`、`order/` | OK |
| 节点列表 / 订阅 URL | ✅ `/user/server/fetch` `/client/subscribe` | ✅ `nodes/nodes_page.dart` | OK |
| 公告 (notice) | ✅ `/user/notice/fetch` | ✅ `/announcements` | OK |
| 工单 (ticket) | ✅ `/user/ticket/*` | ✅ `/support` | OK |
| 知识库 / FAQ | ✅ `/user/knowledge/fetch` | ✅ `/faq` `/support` | OK |
| 邀请码 / 邀请详情 / 佣金转余额 | ✅ `/user/invite/save` `/invite/fetch` `/invite/details` `/user/transfer` | ✅ `/invite` `/invite-records` | **路径不一致** ⚠ |
| 用户信息 / 改密码 / 自动续费 / 流量提醒 | ✅ `/user/info` `/user/changePassword` `/user/update` | ✅ `settings/` | OK |
| 在线设备 / 强制登出 | ✅ `/user/getActiveSession` `/user/removeActiveSession` | ❌ 未实现 | 后端多 |
| 礼品卡兑换 | ✅ `/user/redeemgiftcard` | ❌ 未实现 | 后端多 |
| Telegram 解绑 | ✅ `/user/unbindTelegram` | ❌ 未实现 | 后端多 |
| 重置 token / uuid | ✅ `/user/resetSecurity` | ❌ 未实现 | 后端多 |
| **签到 / Checkin** | ❌ **后端无相关路由** | ✅ `/checkin` 页 + `checkin_data_source` 调 `/user/checkin*` | **客户端多余 — 调用必 404** ❌ |
| 抽奖 / 任务系统 | ❌ | ❌ | OK |
| 客服 (Crisp WebView) | — | ✅ | 第三方，与后端无关 |
| Telegram 群外链 | 由 `/user/comm/config` 下发 URL | ✅ | OK |

### 重要不匹配

1. **签到（Checkin）**
   - 客户端：`lib/presentation/pages/checkin/checkin_page.dart` 完整实现，调用 `/api/v1/user/checkin*`。
   - 后端：`AppRoute.php` / `UserRoute.php` 都**没有** `checkin` 路由，控制器目录里也无 `CheckinController`。
   - 入口：首页顶部图标 (`velox_home_page.dart`)，受 `RemoteConfig.showCheckin` 控制，但**默认值为 true**，意味着后端不下发 false 时入口直接暴露并 404。

2. **邀请记录**
   - 客户端 `invite_records_page.dart` → datasource 调用的是 `/api/v1/user/invite/unifiedDetails`。
   - 后端只有 `/user/invite/details`（标准 V2Board 接口）。
   - **必现 404**，需修正 endpoint 或改字段映射。

---

## 2. 客户端"多余 / 不该出现"的功能（不限平台）

| 项 | 出现位置 | 后端状态 | 建议 |
| --- | --- | --- | --- |
| 签到页 `/checkin` | `velox_home_page.dart` 顶部入口；`checkin_page.dart` 整页 | 后端无 `/user/checkin*` | 全平台隐藏，并把 `RemoteConfig.showCheckin` 默认值改为 `false`（或直接删除代码） |
| `invite-records` 的 endpoint | `lib/data/datasources/remote/invite_remote_data_source.dart` | 字段名不一致 | endpoint 改 `/invite/details`，按返回结构调整 model |

---

## 3. macOS 桌面端额外该裁剪的项

`MainPage` 已经做了一层桌面差异（侧栏 + 隐藏"偏好/关于"），但还有几处对桌面端体验不友好或冗余：

| 项 | 当前状态 | 建议 |
| --- | --- | --- |
| **引导页 onboarding** | Splash 已在桌面端跳过 (`splash_page.dart`) | ✅ 已处理 |
| **首页签到入口** | `RemoteConfig.showCheckin` 默认 true | 全平台硬隐藏（后端无此接口） |
| **首页公告入口** | `RemoteConfig.showAnnouncement` 默认 true | 后端支持，保留 |
| **登录页 QR 扫码导入** | 全平台显示 | macOS / Windows 隐藏入口（无前置摄像头使用场景），保留 `/url-import` |
| **首页右下"邀请"浮动按钮** | 桌面右下 24px | 桌面侧栏加"邀请"项替代，移除浮动按钮 |
| **iOS 支付探测** | `subscription_page.dart` 已用 `Platform.isIOS` 隔离 | OK |

---

## 4. 现有动态裁剪机制

客户端有两层开关，做裁剪时优先复用：

### 4.1 平台硬判断 `Platform.is*`

| 文件 | 用途 |
| --- | --- |
| `main_page.dart` L116 | macOS/Windows → 侧栏布局；其他 → 底栏 |
| `velox_home_page.dart` L73, L104 | 桌面端连接按钮 220dp（手机 272dp）、底部间距 32px（手机 96px） |
| `settings_page.dart` L443 | 桌面端隐藏"偏好设置"和"关于" |
| `nodes_page.dart` L67 | Windows 强制禁用 TUN |
| `subscription_page.dart` L63 | iOS 支付预检 |

### 4.2 后端下发的 RemoteConfig

可由后端 `/user/comm/config` 或 `/app/config` 下发，无需改客户端：

- `showCheckin` — 首页签到入口
- `showAnnouncement` — 首页公告入口
- `faqEnabled` — 设置页 FAQ
- `siteName`、`websiteUrl`、`telegramUrl`

> ⚠ 默认值若为 `true`，后端未下发就会暴露入口。**签到入口建议改默认 false 或硬删**。

---

## 5. 推荐的具体动作（按改动量从小到大）

### Tier 1 — 必做（消除 404 / 接口不匹配）

1. 隐藏首页签到入口 + 移除 `/checkin` 路由 + 删除 `checkin_page.dart` 与对应 datasource。
   - 或最低限度：将 `RemoteConfig.showCheckin` 默认改为 `false`，并在 `router.dart` 移除 `/checkin` 路由注册。
2. 修正 `invite-records` 的 endpoint：
   - `/invite/unifiedDetails` → `/invite/details`
   - 对照后端 `InviteController@details` 返回结构调整 model。

### Tier 2 — macOS 端体验裁剪

3. 登录页"扫码导入"入口在 `Platform.isMacOS || Platform.isWindows` 时隐藏。
4. 首页右下"邀请"浮动按钮在桌面端隐藏，改放侧栏入口。

### Tier 3 — 可选增强（非裁剪，是补足）

5. 增加"礼品卡兑换"入口（后端 `/user/redeemgiftcard` 已支持）。
6. 增加"已登录设备"管理（后端 `/user/getActiveSession` `/user/removeActiveSession` 已支持）。
7. 增加"Telegram 解绑"入口（如果产品流程需要）。

---

## 6. 涉及的关键文件清单

### 客户端待改动
- `lib/app/router.dart` — 移除 `/checkin` 路由（Tier 1）
- `lib/presentation/pages/home/velox_home_page.dart` — 移除签到入口、桌面端移除浮动邀请按钮
- `lib/presentation/pages/checkin/checkin_page.dart` — 删除（Tier 1）
- `lib/data/datasources/remote/checkin_remote_data_source.dart`（若存在）— 删除
- `lib/data/datasources/remote/invite_remote_data_source.dart` — 修正 endpoint
- `lib/presentation/pages/auth/login_page.dart` — 桌面端隐藏 QR 导入入口
- `lib/presentation/pages/home/main_page.dart` — 桌面端侧栏增加"邀请"项
- `lib/core/services/remote_config_service.dart` — `showCheckin` 默认改 false（如保留代码）

### 后端无需改动
本次裁剪仅前端调整；如果未来要补客户端没实现的功能（礼品卡、设备管理），后端已就绪。

---

## 7. 状态汇总

- ✅ 已处理：splash → 桌面端跳过 onboarding（`splash_page.dart`，上一轮提交）
- ⏳ 待处理：本文档 §5 的 Tier 1 / Tier 2
- 📝 备选：本文档 §5 的 Tier 3
