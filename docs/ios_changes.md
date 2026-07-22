# iOS 改动记录

> 最后更新：2026-03-30

---

## 1. iOS 独立支付开关（后端 + 客户端）

**背景：** App Store 合规要求，iOS 客户端不能显示外部支付方式。

### 后端改动
| 文件 | 改动 |
|------|------|
| `database/update.sql` | `v2_payment` 表新增 `ios_enable` 字段（tinyint，默认 0） |
| `app/Http/Controllers/V1/Admin/PaymentController.php` | 新增 `showIos()` 方法，切换 iOS 支付状态 |
| `app/Http/Routes/V1/AdminRoute.php` | 新增路由 `POST /api/v1/admin/payment/showIos` |
| `app/Http/Controllers/V1/User/OrderController.php` | `getPaymentMethod` 检测 `X-Client-Type: ios` 请求头，iOS 只返回 `ios_enable=1` 的方式 |

### 客户端改动
- iOS 所有 API 请求携带 `X-Client-Type: ios` 请求头
- `lib/presentation/pages/home/main_page.dart`：根据支付方式返回结果，动态显示/隐藏订阅 Tab（3 Tab vs 4 Tab），`_iosPayEnabled` 控制

---

## 2. iOS 版本更新 — 完全不参与应用内更新

iOS 不做 OTA 更新，只能通过 App Store 更新。

| 文件 | 改动 |
|------|------|
| `lib/core/services/remote_config_service.dart` | `checkForUpdate()` 开头加 `if (Platform.isIOS) return null` |
| `lib/presentation/pages/home/main_page.dart` | 更新检测包在 `if (!Platform.isIOS)` 中 |
| `lib/data/models/remote_config_model.dart` | `RemoteUpdateConfig` 只有 `android/windows/macos` 字段，无 `ios` |
| `android/app/src/main/AndroidManifest.xml` | 新增 `REQUEST_INSTALL_PACKAGES` 权限（仅 Android） |

**各平台更新行为：**
| 平台 | 行为 |
|------|------|
| iOS | 完全跳过，不检测，不弹窗 |
| Android | 应用内下载 APK → 系统安装器 |
| Windows | 下载 .exe → 自动启动安装 |
| macOS | 下载 .dmg → 自动打开 |

---

## 3. iOS 26 安全存储崩溃修复（临时方案）

**问题：** `flutter_secure_storage` 在 iOS 26 上插件注册阶段崩溃，导致 App 无法启动。

**临时修复：** `lib/core/storage/secure_storage.dart` 改用 `SharedPreferences` 替代。

**⚠️ 注意：** Token 目前以明文存储在 SharedPreferences，存在安全风险。待 `flutter_secure_storage` 修复 iOS 26 兼容性后需还原为加密存储。

---

## 4. iOS VPN 功能现状

UI 动画和权限请求正常，但实际流量代理不通。

### 已完成
- Flutter ↔ iOS 原生通信（MethodChannel + EventChannel）
- `NETunnelProviderManager` 调用，系统 VPN 权限弹窗，状态栏 VPN 图标
- sing-box JSON 配置生成逻辑

### 待修复（4 个问题）

| # | 问题 | 位置 |
|---|------|------|
| 1 | 缺少 `Libbox.xcframework` | `packages/singbox_flutter/ios/Frameworks/`（目录为空） |
| 2 | `PacketTunnelProvider.swift` 是空壳 | `startSingbox()` 只设布尔值，未调用 Libbox |
| 3 | App Group ID 不一致 | `Runner.entitlements` vs `SingboxFlutterPlugin.swift` |
| 4 | 流量统计硬编码为 0 | `getUploadSpeed()` 等全部 `return 0` |

### 修复路径
1. 从 sing-box releases 下载 `Libbox.xcframework`，放入 `packages/singbox_flutter/ios/Frameworks/`
2. 解注释 `PacketTunnelProvider.swift` 中的 `LibboxNewService` / `LibboxStartService` 调用
3. 统一 `Runner.entitlements` 和 `SingboxFlutterPlugin.swift` 中的 App Group ID
4. 接入 Libbox 流量统计 API 替换硬编码 0

---

## 5. iOS 通知系统

- 使用 `flutter_local_notifications` 包
- 触发机制：前台 30 分钟轮询 / App 恢复时立即检查 / iOS 后台 Fetch
- **关键配置：** 前台通知需设置 `defaultPresentAlert: true`，否则 App 在前台时通知不弹出
- 通知内容来源：V2Board `/api/v1/user/notice/fetch` 接口

---

## 6. iOS WebView（客服页面）

- 使用 `webview_flutter_wkwebview` 嵌入 Safari WebKit
- Crisp 客服界面在 App 内展示，不跳转外部浏览器
