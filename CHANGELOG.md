# Changelog

所有版本变更记录在此。格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/),版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.0.12+13] - 2026-07-22

### Added(「我的」页账号身份行)
- 🆕 **标题「我的」下方显示当前登录邮箱** —— 此前 `settings_page.dart` 已取出 `state.user.email` 却从未使用(死代码),邮箱在全 App 无处可见,用户报障时要自己去用户中心翻。现在紧贴页面标题渲染一行 13px / `v.text3` 灰字 + 复制图标。
- 🆕 **点击整行复制邮箱** —— `Clipboard.setData` + 复用本页既有的 `_showStatusToast(l10n.copySuccess)` 玻璃态弹窗,不新增反馈模式。直接服务「客服问您的注册邮箱是」这个高频场景。
- 🆕 **桌面端手型光标** —— 外层包 `MouseRegion(cursor: SystemMouseCursors.click)`,macOS/Windows 鼠标悬停可见可点性;移动端为 no-op。

### Design Rationale
- **不放进套餐卡**:套餐卡的叙事链是「套餐名 → 到期 → 用量 → 进度条 → 续费 CTA」,属商品维度;邮箱属账号维度,塞进去会把卡片从 5 层信息推到 6 层,且左上角被 chip、右上角被刷新/续费占满,顶部已无干净位置。
- **不做「用户中心」的 subtitle**:语义虽准,但列表项的点击行为被导航占用,用户无法复制——而复制正是这个信息的核心用途。
- **视觉重量刻意压低**:`v.text3` 灰 + 13px,身份是锚点不是行动项,不与套餐卡的「续费」主 CTA 抢焦点。
- **无条件显示(不限 `hasPlan`)**:未订阅用户更容易注册多个号搞混,身份确认对他们反而更重要。
- **l10n 零新增**:`copySuccess` 简中/繁中/英三语均已存在。

### Notes
- Android 13+ 系统自带剪贴板预览条,复制后会与本 App 的居中 toast 形成双重反馈。保留 toast 是为了跨平台反馈语言一致(iOS / Android 12 及以下无系统条),后续如需可单独为 Android 13+ 关闭。

## [1.0.11+12] - 2026-07-18

### Fixed(公告栏 HTML 渲染 bug)
- 🐛 **公告 `<a>` 标签 `target="_blank">` 泄漏成明文** —— 后端公告内容里如果 HTML 标签属性跨多行(如 `<a href="url"\ntarget="_blank">`),`NoticeModel.contentHtml` 里 `s.replaceAll('\n', '<br>')` 会把标签打断为 `<a href="url"<br>target="_blank">`,flutter_html 解析失败,后续 `target="_blank">下载链接` 就以文本形式泄漏到 UI 上(用户实测截图证实)。
- 修法:在 `\n → <br>` 转换**之前**,先用正则 `RegExp(r'<[^>]*>')` 遍历所有 HTML 标签,把标签内部的换行/多余空白折叠成单空格,保护标签结构不被下一步破坏。段落级换行(标签外的 `\n`)照常转 `<br>` 保留视觉分段。
- 影响面:所有历史公告一并修好(此改动只是渲染前的规范化,不改后端数据)。

## [1.0.10+11] - 2026-07-17

### Added(自动更新卡死检测)
- 🆕 **下载 30s 无进度自动判定 stall** —— `AppUpdater.downloadAndInstall` 内加 `Timer.periodic(5s)` 巡逻,onReceiveProgress 每次回调无条件刷 `lastTick`(兼容 chunked/无 Content-Length 场景);30s 无字节到达 → `stalledFlag=true` + `cancelToken.cancel('stalled')`
- 🆕 **`AppUpdateResult.stalled` 枚举**:下载卡死独立结果类型,与普通 cancelled / downloadFailed 区分
- 🆕 **InAppUpdateDialog stalled UI**:卡死时 `showVeloxSnack("当前版本 vX.X.X,更新失败,请联系客服", isError:true)` + 对话框按钮切换为 `[关闭][重试]` Row
- 🆕 **强制更新场景也能关闭** —— `[关闭]` 按钮走 `Navigator.of(context).pop()`,主动 pop 不受 `barrierDismissible: false` / `PopScope canPop: false` 拦截,即使 `must:true` 也能退出

### Fixed(preship 抓到的一个 major bug)
- 🐛 **stall 计时窗口从 dio.download 开始起算,不是函数入口** —— 之前 `lastTick` 在函数入口初始化,若 Android 8+ 首次授权"安装未知应用"跳系统设置耗时 >25s,Timer 首 tick 立刻误判 stalled → 用户看到"更新失败"但网络正常。修复:在 `Timer.periodic` 创建前显式 `lastTick = DateTime.now()`,授权耗时不再污染 stall 判定。

### Design Rationale
- **try/catch/finally 重构**:所有 return/throw 分支(insecureUrl/permissionDenied/checksumFailed/xattrFailed/openFailed/cancelled/stalled/downloadFailed/success)都保证 `stallTimer?.cancel()` 在 finally 里兜底,防 Timer 泄漏跨越 SHA256 校验阶段污染状态
- **stalledFlag 布尔位区分 cancel 语义**:同一 `CancelToken` 承载两种 cancel(用户主动 / stall 触发),`catch on DioException` 优先判 `isCancel(e) && stalledFlag` → 返回 stalled,否则维持 cancelled
- **复用 showVeloxSnack**:与全 app 玻璃态 SnackBar 视觉一致,不新增依赖不改现有组件
- **stall 阈值 30s + 巡逻 5s**:网络切换/CDN 抖动通常 <10s 恢复,30s 是"确认卡死而非临时抖动"的稳妥阈值;5s 巡逻粒度足够检出且对 CPU 无感

## [1.0.9+10] - 2026-07-11

### Changed(通知功能诚实降级)
- 🔄 **"通知推送"整个功能重设计** —— 承认之前实现是装饰品(Android 100% 无效,iOS/macOS 命中率 <10%),彻底改造:
  - 设置 → 偏好里"通知推送"toggle **消失**(Windows/Android/iOS/macOS 全消失)
  - 首页顶部**喇叭图标**在有新公告时**亮小红点**,点进公告页红点即消
  - 5 处 Android/iOS 后台唤醒的 stub 死代码全部删除

### Fixed(4 个 v1.0.8 遗留 bug)
- 🐛 **Android 完全无效** —— NotificationService `_supported = iOS || macOS` 让 Android 通知栈从未 init,toggle 存 pref 但零效果;新设计跨全平台一致工作
- 🐛 **iOS BGFetch stub** —— AppDelegate.swift 的 `performFetchWithCompletionHandler` 只写了 `completionHandler(.newData)`,从不 invokeMethod 到 Dart;Info.plist 声明了 `UIBackgroundModes=fetch` 却没实际用,App Store 审核会追问,一并清理
- 🐛 **首装误推老公告** —— 旧版首次安装 `last_notice_id=0`,第一次 tick 立刻把当前 max id 当"新公告"推;新版走"种子路径",首次拉到的 max id 只写库不亮红点
- 🐛 **i18n 硬编码** —— 旧版 `title: '📢 新公告'` 硬编码中文,新版走 l10n(其实新版无需 title,直接红点即可)

### Removed(减 200+ 行代码 + 1 依赖)
- 🗑️ 删除 `lib/core/services/notification_service.dart` **整文件**(110 行,DarwinInitializationSettings/权限申请/showAnnouncementNotification)
- 🗑️ 删除 `lib/core/services/announcement_poll_service.dart`(改写为 announcement_badge_service.dart)
- 🗑️ 删除 pubspec `flutter_local_notifications: ^18.0.0` 依赖
- 🗑️ 删除 preferences_page.dart 里 4 个方法(`_loadNotificationState` / `_onNotificationToggle` / `_openSystemNotificationSettings` / `_showPermissionDeniedDialog`)+ 5 个 import + 2 个 state var,~120 行
- 🗑️ 删除 main.dart 里 iOS `MethodChannel('com.velox.app/background')` handler 整块
- 🗑️ 删除 iOS `AppDelegate.swift` 里 `setMinimumBackgroundFetchInterval` + `performFetchWithCompletionHandler`
- 🗑️ 删除 iOS `Info.plist` 里 `UIBackgroundModes=fetch` 声明
- 🗑️ 删除 3 个 l10n 文件里 5 个键:`notificationPush` / `notificationPushSubtitle` / `notificationPermissionRequired` / `notificationPermissionContent` / `goToSettings`

### Added(新的红点服务)
- 🆕 `lib/core/services/announcement_badge_service.dart` —— `ValueNotifier<bool> hasUnread` + `initialize()` 迁移旧键 + `refresh()` 拉后端公告 + `markAllRead()` 幂等清红点 + 前台 30 分钟兜底轮询
- 🆕 首页 `_VeloxTopBar` 喇叭图标改成 `ValueListenableBuilder<bool>` 包裹的 `Stack + Positioned` 红点(8×8 圆形 `#EF4444`),`clipBehavior: Clip.none` 允许超出 icon 边界

### Migration(自动,无需用户干预)
- 存量用户升级:`AnnouncementBadgeService.initialize()` 冷启动时执行一次性迁移:
  1. 无条件 `prefs.remove('notifications_enabled')`(toggle 已删)
  2. 若有旧 `last_notice_id`,平移到 `last_read_notice_id`(语义等价:老版"已推过"= 新版"已读")
  3. 若两键都不存在(真·首次安装),首次 refresh 拉到的 max id 只写库不亮红点
- iOS 系统里已授权的通知权限不动(无法从 app 内吊销,也无必要)

### Design Rationale
- **行业验证的最小可行方案** —— Shadowrocket/Mullvad/Xboard/v2board 前端都是"启动拉一次 + banner + 已读回写"这套,不做 FCM/APNs/长连接
- **诚实优于完美** —— 大陆 60%+ Android 无 GMS,FCM 送达率 <30%;华米OV 混合推送需企业营业执照 + 商店审核,VPN 类应用 100% 被拒;SSE 长连接在移动端切后台立即断,收益极小 —— 与其做一个"时灵时不灵"的伪推送,不如干脆做一个"打开 App 就能看到"的红点,用户预期与实际能力 100% 一致
- **紧急事件走 TG 频道兜底** —— 客户端只做非紧急公告红点,紧急情况(IP 大规模封禁/跑路预告)靠用户订阅 TG 频道

## [1.0.8+9] - 2026-07-11

### Changed(错误呈现层最终形态)
- 🔄 **过度设计一次性清盘** —— 承认 v1.0.7 引入的错误码体系过度工程,砍到最小:
  - 删除 `diagnostic.dart` 整文件(DiagnosticInfo/traceId 生成器/客服诊断包 —— 用户不需要,截图更快)
  - 删除长按 3s 复制诊断包功能(RawGestureDetector/LongPressGestureRecognizer/HapticFeedback/Semantics 全部砍掉)
  - 删除 `AppException.isBusiness` 字段 + `AuthError.isBusiness` 字段 + `AuthBloc` 里的 isBusiness 提取
  - 删除 `_throwBusiness` 助手 —— 业务错误 revert 到 `throw Exception(V2Board 原文)`
  - 删除 `ErrorSnackbar` 组件(默认 Material SnackBar,视觉与其他页不一致)
  - 删除 `showVeloxSnack` 的 `showCode` 参数 —— 简化为"有 code 就显示,没 code 就不显示"
- 🔄 净删除约 200 行代码 + 1 个 dart 文件

### Fixed(v1.0.7 UI 遗留)
- 🐛 **错误 snack 视觉统一** —— 现在全 app 只有一个 `showVeloxSnack` 玻璃态组件(红边 + info 图标),登录页与其他页视觉完全一致,不再有默认 Material 白/黑底的第二种样式
- 🐛 **单行 error 码格式** —— 基础设施错误显示"文案（error:1003）"单行,替换掉之前两行(主文案 + VX-1003 小字灰色)的样式。VX- 前缀剥离,更精简
- 🐛 **`(error:XXXX)` 格式对齐用户偏好** —— 之前是 `VX-1003` 小字灰色独立行,现在改成 `（error:1003）` 单行嵌入文案

### Behavior Rule(判定规则,极简)
- **业务错误**(V2Board 返回 `{status:fail, message: "邮箱或密码错误"}`)→ `auth_remote_datasource` 抛裸 `Exception` → AuthBloc 的 `code = (e is AppException) ? e.veloxCode : null` 得 null → snack 只显示干净文案
- **基础设施错误**(dio 超时/连接错/HTTP 5xx/HTML 兜底页)→ `api_client._handleResponseError` 抛 `AppException(veloxCode: XXXX)` → snack 追加"（error:XXXX）"

### 用户可见 error 码(全 app 只有 4 个)
- `error:1002` — 请求超时(所有超时类型合并)
- `error:1003` — 网络连接失败(TCP reset/DNS 挂/断网/OSS 不可达)
- `error:2050` — 服务器繁忙(500/502/503/504/429 合并)
- `error:9000` — 未知错误(SSL 挂/dio 未分类)

其他 36 个 VX 枚举值虽然在 `error_code.dart` 中定义,但生产代码路径不会触发,属装饰性/号段占位。

### V2Board 后端同步(部署但独立于客户端)
- 🆕 admin 面板新增"安卓在线人数"卡片(挂在"实时注册"旁)—— 数据源 Redis ZSET `velox:online:android`,由客户端 `velox/sync` 心跳写入,11 分钟窗口 zcount 计数
- 🆕 后端新增路由 `GET /api/v1/{secure_path}/stat/getAndroidOnline`
- 🆕 客户端 sync 端点透明追加 Redis::zadd 心跳,try/catch 保护不影响业务

## [1.0.7+8] - 2026-07-10

### Changed(核心重设计:VX 码只用于基础设施错误)
- 🔄 **业务错误 / 基础设施错误双轨呈现**:
  - **业务错误**(V2Board HTTP 200 + envelope status:fail —— 密码错/账号封禁/邀请码无效/验证码错/注册频繁 …)= 单行干净文案,**不带 VX 码**,不带长按复制。
  - **基础设施错误**(dio timeout/connectionError/HTML兜底页/5xx/hedge exhaust/SSL/DNS)= 两行 + VX 码 + 长按复制诊断包。
  - **鉴别信号**:唯一命中"HTTP 200 + ApiResponse.isSuccess=false"这个 seam,即 `auth_remote_datasource.dart` 的 4 处业务失败位。
- 🔄 `AppException` 新增 `isBusiness` 字段(默认 false),仅 datasource 的 `_throwBusiness` 助手会打 true。所有 infra 子类(Network/Server/Auth/Timeout/Validation/Cache)天然默认 false,行为不变。
- 🔄 `AuthError` state 增加 `isBusiness` bool,`AuthBloc` 6 处 catch 从 `AppException.isBusiness` 提取。
- 🔄 `ErrorSnackbar.show` 增加 `showCode: bool = true` 参数,业务错误分支渲染成单行 Text(不带 GestureDetector 长按)。

### Fixed(修复登录错误诊断的根因)
- 🐛 **所有 V2Board 业务错误坍缩到 VX-9003 的根因**:`auth_remote_datasource.dart` 的 login/register/sendEmailCode/forgotPassword 4 处原来抛的是**裸 `Exception()`**(不是 `AppException`),导致下游 `(e is AppException) ? e.veloxCode : VeloxErrorCode.unknownAuth` **必然**兜底到 VX-9003。修复:统一走 `_throwBusiness()` 助手 → `ErrorMessageMapper.mapWithCode()` → 抛 `AppException(isBusiness: true, veloxCode: <真实码>)`。现在 VX-3011/3013/3020/3110/3201 等业务码全部激活(虽然 UI 端会隐藏 VX 显示,但底层码有意义,便于日志/客服)。
- 🐛 **补齐 V2Board 中文错误映射(15 条精确 + 3 条模糊)**:对齐 zh-CN.json 的真实翻译:
  - **登录**:`该账户已被停止使用`/`令牌有误`/`该用户不存在` + 源码 typo `The user does not `
  - **注册**:`本站已关闭注册`/`验证码有误`/`邮箱验证码有误`/`邮箱验证码不能为空`/`邮箱已在系统中存在`/`邮箱后缀不处于白名单中`/`不支持 Gmail 别名邮箱`/`注册失败`
  - **找回密码**:`该邮箱不存在系统中`/`重置失败`/`重置失败，请稍后再试`
  - **动态 :minute 变量**(Laravel 已替换):`密码错误次数过多` / `注册频繁` / `发送频繁` → 新增 `_chinesePartialMappings` 有序 contains-match(在精确匹配后、英文匹配前执行,防止被英文关键词误吞)。

### Design Rationale(设计动机)
- **用户核心洞察**:"错误代码只是在app中登录的时候对于(oss中host里的api连通信不佳)的场景提示的" —— VX 码只应出现在**基础设施连接问题**(OSS/host.json/config.json/API host 挂),不应出现在**业务失败**(密码错/账号封禁)。
- **消费级 App 惯例**:Slack/Discord/微信登录密码错时不会显示 "Error VX-3011",只显示 "密码错误"。VX 码是**排障工具**,不是**用户信息**。
- **保留 VX 显示的场景**(客服排障需要):网络/超时/5xx/OSS 不可达/所有 API host 挂/CDN HTML 兜底页 —— 这些用户看到 VX 码后可以长按复制诊断包发给客服,精准定位是链路哪一环挂了。

## [1.0.7+8-pre-error-split] - 2026-07-09

### Added(新增)
- 🆕 **错误码体系**: 引入 `VeloxErrorCode` 枚举(40 个 VX-xxxx 码值),覆盖网络/HTTP/认证/订阅/Native/客户端状态 7 个大类
- 🆕 **`DiagnosticInfo`**: 用户可复制的诊断包(含错误码/时间/版本/host hash/native code),客服工单一键定位
- 🆕 **`ErrorSnackbar` 组件**: 主文案 + 灰色小字错误码,长按 5s 复制诊断包
- 🆕 **`HostHealth` + `HostHealthRegistry`**: per-host 简化 CB(连续 3 次失败 30s 冷却)
- 🆕 **`FailoverInterceptor`**: 请求驱动 hedge —— 连接错/5xx/基础设施 4xx(CDN 兜底 HTML)自动切下一个 host
- 🆕 **Sticky TTL 24h**: 超过 24h 或版本变化自动重赛 host,防止老用户永久卡在死域名
- 🆕 **详细错误码手册**: `docs/error-codes/README.md` + 每个大类子文档

### Changed(修改)
- 🔄 `AppException` 基类增加 `code: VeloxErrorCode` 字段(可选,向后兼容默认 unknown)
- 🔄 6 个 Exception 子类默认 code:NetworkException=networkFailed / ServerException=serverBusy / AuthException=loginExpired / ValidationException=validationFailed / TimeoutException=requestTimeout / CacheException=configLoadFailed
- 🔄 `ErrorMessageMapper` 新增 `mapWithCode()` / `fromStatusCodeWithCode()` 返回 `ErrorMapping`(errorKey + VeloxErrorCode)
- 🔄 `ApiEndpointManager.recordFailure` 现在把"基础设施 4xx"(text/html body + nginx 兜底页)计入失败,不再只算 5xx
- 🔄 `login_page` 的 AuthError 弹窗改用 `ErrorSnackbar`,显示 VX 码
- 🔄 清理 `api_client.dart:_shouldHedge` 里 unreachable default 分支(DioExceptionType enum 已穷举)
- 🔄 **版本更新检查触发点前移到 Splash**: 从"登录后进主页才检查"改成"App 打开就检查",符合消费级"打开就查"的用户预期。未登录用户也能看到强制更新提示。改动:`splash_page.dart` initState 追加 `_autoCheckUpdate()`,MainPage 保留双保险机制。

### Fixed(修复)
- 🐛 **登录报"操作失败,请稍后再试"的主因** —— sticky 到 aqshx1/x7jax 死 API 域后,404 nginx HTML 兜底页被识别为 host 层不可用,自动 failover 到 ad,用户无感登录成功
- 🐛 客户端不再在 sticky 到坏域名后无限卡死,连续 3 次失败自动冷却 30s
- 🐛 **冷启动 token 恢复健壮性**: `isLoggedIn` catch 精细化 —— 只在明确 `AuthException` 时清 token 掉登录页;网络错/超时/5xx 保守保留登录态,让主界面业务请求自己处理。避免"冷启动网络慢 = 被迫重登"的糟糕体验。
- 🐛 **`verifyToken` 类型化异常**: 抛的原生 `Exception` 改成 `AuthException`(登录相关消息)或 `ServerException`(其他),让上层 isLoggedIn 能正确分流。
- 🐛 **消费级 token 铁律(Slack/Discord/Notion 通用)**: 移除 `api_client.dart:_onError` 拦截器里的 `_secureStorage.delete(authToken)`。清 token 的唯一入口收敛为 `isLoggedIn` 冷启动校验(遇 `AuthException` 时清)+ 用户主动登出。这样后端偶发 blip(风控 / 限流 / 短暂 401)不会误伤 token,用户下次冷启动若 blip 恢复,直接秒进主界面无感。
- 🐛 **修复 MainPage 重复弹更新框风险**: 删除 `main_page.dart` initState 里的 `RemoteConfigService.startupChecksRun = false;` reset —— 之前每次 MainPage 重建都重置 guard,现在配合 Splash 的检查,同一 session 只弹一次(guard 同步 set 防 race)。
- 🐛 **过期提醒横幅硬编码 bug**: 之前 `velox_home_page.dart:487` 有一行 demo 遗留 `const daysLeft = 5;`,导致横幅永远显示"还剩 5 天",与用户真实剩余天数无关;阈值判断也被一起注释掉。修复:恢复 `expire.difference(DateTime.now()).inDays` 真实计算 + 恢复"仅在 0~notice.days 窗口内提醒"守门条件。
- 🐛 **登录错误码硬编码 VX-9003 bug**: 之前 `login_page.dart` 里 `ErrorSnackbar.show` 的 code 硬编码为 `VeloxErrorCode.unknownAuth (VX-9003)`,所有登录失败(密码错/网络断/超时/账号封禁)都显示同一个兜底码,客服排障时无法区分具体原因。修复:`AuthError` state 加 `veloxCode` 字段,`AuthBloc` 的 6 处 catch 从 `AppException.veloxCode` 提取真实码,`login_page` 用 `state.veloxCode`。现在:密码错 → VX-3011,超时 → VX-1002,网络断 → VX-1003,服务器 500 → VX-2050,账号封禁 → VX-3014。

### Decided Not To Do(考虑后决定不做)
- 🚫 **真业务 endpoint 探针 (P1-4 曾拟)**: 曾经在 RemoteConfigService 里加双探针(同时打 /velox/config.json + /api/v1/guest/comm/config)以过滤"nginx 活但 /api 死"的死站。
  - **不做原因**: `FailoverInterceptor + isInfrastructure4xx` (P0-2) 已经在请求路径上识别 nginx 404 HTML 兜底页,POST 请求本身就是探针。
  - 探针只优化了"冷启动第一次登录快 1-2s",没解决新问题;却增加冷启动开销 300-800ms + 40 行代码复杂度。
  - 属于**过度设计**,遵守 YAGNI 原则不做。
  - 备份 `.pre-p1-4.bak` 已在验证通过后删除,若未来运营发现死站过多难以维护,再重开讨论。
- 🚫 **AuthEventBus + AuthBloc 订阅拦截器信号 (曾拟必修 3)**: 深度对抗 review 曾担心"拦截器不清 token → 运行时 401 僵尸态"。但行业调研发现:主流消费级 App 就是这么做的 —— 运行时 401 只 emit snackbar,让业务请求自然表达,不主动 kick 到登录页。用户下次冷启动 verifyToken 自然处理。**若未来运行时 401 用户投诉上升(用户反馈"看到很多操作失败"),再引入 AuthEventBus 让 AuthBloc 订阅拦截器信号立即跳登录页。**

### Research Note(研究备注)
- **消费级 token 惯例**:Slack/Discord/Notion/TikTok/WeChat 通行做法是"一次登录长期在线",拦截器**永远不清 token**,只有 refresh 明确返回 `invalid_grant` 或用户主动登出才清。V2Board 后端目前是永久 token 模型(无 refresh 概念),我们对齐消费级路线,不学网银的短 access + 强校验模式。
- **参考**: OAuth 2.0 RFC 6749 / RFC 9700 / Auth0 Refresh Token Rotation / Firebase Auth SDK.
- **长期演进**: 待 V2Board 后端加 refresh_token 端点 + rotation 后,再上完整消费级基线。

### App 更新时 token 保留策略(明确决定)

- **决定**: App 版本更新时(相同 `velox-release.jks` keystore 覆盖安装,或 Play Store 自动更新)**保留 token,不强制重登**。
- **理由**: Android 覆盖安装默认保留 SharedPreferences,消费级 App(Slack/Discord/微信/TikTok)通用做法就是"更新不清 token"。用户体验优先。
- **不做**: 版本变化时主动清 token(常见于金融/网银 App 的偏保守做法)。Velox 不需要这种偏保守策略。
- **触发重登的完整列表**(仅这 4 种):
  1. 用户主动"退出账号"
  2. V2Board 网站改密码(cold start verifyToken 抛 AuthException)
  3. 用户手动"清除应用数据"或卸载重装
  4. V2Board 后端 `SESSION_LIFETIME` 到期(建议服务器改为 30-365 天)
- **App 更新触发重登**: **否**(除非用户选择卸载重装)。

### Reference(参考)
- Mullvad Access Methods 序列表
- Windscribe wsnet::FailoverStrategy
- Netflix Hystrix / Resilience4j
- Cloudflare 错误码格式(VX-xxxx 类似 Error 1020 模式)

### Deprecated(即将废弃)
- 无

### Removed(移除)
- 无

### Security(安全)
- 无

---

## [1.0.6+7] - 2026-07-09

### Fixed(修复)
- 🐛 `.env` `OSS_URL` 更换为 3 桶阿里云 OSS 容灾(具体 bucket 名不入库)
- 🐛 新增 `OSS_URLS` 多桶并发赛跑,消除单点 OSS 依赖

### Changed(修改)
- 🔄 备份老 `.env`(带时间戳后缀)

---

## [1.0.5+6] - 2026-07-05

### Added(新增)
- 🆕 mihomo 内核 patch:hub/route/patch_android.go 里的 SetEmbedMode(true) 已删,PATCH /configs 恢复可用(cmfa 保留,DNS patch 保留)
- 🆕 Android Kill Switch(P0 保命):PROXY 选择器切 REJECT 阻断所有出站,tun 保持不断开,防真实 IP 泄漏
- 🆕 Fast Switch:节点切换走 mihomo API PUT /proxies/PROXY,不重启内核

### Fixed(修复)
- 🐛 P1-1 FGS lifecycle:startForeground 提前到 scope.launch 之前,避免 Android 8+ FGS 超时
- 🐛 P1-2 tun fd 泄漏:失败路径 Os.close(fd) 兜底
- 🐛 P1-3 Auto-reconnect 竞争:三重 guard(isClosed/status/server)
- 🐛 P1-4 YAML 单引号未 escape:`_yamlScalar` 助手函数
- 🐛 P1-5 Release keystore:从 debug 换 velox-release.jks(SHA-256 f784cd33...)
- 🐛 P2-1 copyWith 覆盖 error:sentinel/clearError flag
- 🐛 P2-2 嵌套 scalar 未 quote:统一走 `_yamlScalar`

---

## [1.0.5+5] 及以前

此版本前无 CHANGELOG,可参考 git log。
