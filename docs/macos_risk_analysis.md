# macOS DMG 分发 — 全景风险分析

## P0 — 致命风险（不修复 = 100% 客户无法使用）

| # | 风险 | 后果 | 修复方案 |
|---|------|------|----------|
| 1 | **sing-box 二进制未打包** | 所有客户连接失败 | 将 `sing-box` Universal Binary (arm64+x86_64) 打包进 `macos/Runner/Resources/` |
| 2 | **Bundle ID 仍是占位符** `com.example.velox` | 权限/签名混乱，SCPreferences 可能拒绝授权 | 改为正式 Bundle ID，如 `com.yourcompany.velox` |

---

## P1 — 严重风险（影响大多数客户）

| # | 风险 | 后果 | 修复方案 |
|---|------|------|----------|
| 3 | **AppDelegate 退出清理缺管理员权限** | App 崩溃或强退后代理残留，客户断网 | 在 `applicationWillTerminate` 中复用 `SingboxFlutterPlugin` 已缓存的 `AuthorizationRef`，而不是用无权限的 shell |
| 4 | **首次连接弹管理员密码框** | 用户点取消 → App 显示"已连接"但无代理 | 弹窗前加说明文字；点取消后强制回到断开状态并提示 |
| 5 | **xattr -cr 对普通用户是障碍** | 非技术用户打不开 App，放弃使用 | 在 README/安装页面提供一键脚本；或走 Apple 开发者公证（notarization） |
| 6 | **仅 arm64，Intel Mac 无法运行** | M 系列以外的 Mac 全部排除 | 构建时加 `--arch x86_64`，或使用 `lipo` 合并 Universal Binary |

---

## P2 — 中等风险（影响部分客户或体验）

| # | 风险 | 后果 | 修复方案 |
|---|------|------|----------|
| 7 | **系统代理 ≠ 全局 VPN** | 游戏、命令行工具、部分 App 流量不走代理 | 在 UI 中明确标注"仅代理浏览器/支持系统代理的应用" |
| 8 | **端口 10808 冲突** | 本机已有其他代理时静默失败 | 启动前检测端口占用，冲突时提示或自动换端口 |
| 9 | **Thread.sleep(0.5) 阻塞主线程** | 连接/断开时 UI 卡顿 0.5 秒 | 改用 `DispatchQueue.global().async` + 回调通知主线程 |
| 10 | **sing-box 启动检测方式脆弱**（1 秒等待） | sing-box 启动慢时误报"连接失败" | 改为轮询检测端口 127.0.0.1:10808 是否可达（最多等 5 秒） |
| 11 | **SCPreferences 需要 `system-network-configuration` 权限** (macOS 13+) | 未签名 App 在新系统上 SCPreferences 写入失败 | 落回 networksetup shell 命令作为降级；或申请 Developer ID 签名 |

---

## P3 — 低优先级风险（长期隐患）

| # | 风险 | 后果 | 修复方案 |
|---|------|------|----------|
| 12 | **配置文件含密码写入 /tmp** | 其他进程可读取节点密码/订阅 URL | 改存到 `~/Library/Application Support/Velox/` 并设 0600 权限 |
| 13 | **AuthorizationRef 不释放** | App 存活期间内存持有授权句柄（可接受，App 退出自动释放） | App 退出时调用 `AuthorizationFree` |
| 14 | **无崩溃上报** | 客户遇到 Bug 无法定位 | 集成 Sentry 或自建崩溃日志上传 |

---

## 法律风险（中国大陆市场）

| # | 风险 | 说明 |
|---|------|------|
| 15 | **未持有 VPN 经营许可证** | 向中国大陆用户提供 VPN 服务违反《电信业务经营许可管理办法》，面临罚款或刑事责任 |
| 16 | **用户数据跨境传输** | 需符合《数据安全法》和《个人信息保护法》的数据本地化要求 |

---

## 修复优先顺序

```
立即修复（发布前必须）：
  #1 打包 sing-box → #2 修改 Bundle ID → #3 修复退出代理残留

发布前建议：
  #4 取消弹窗后强制断开 → #5 提供 xattr 安装说明 → #6 支持 Intel Mac

稳定后优化：
  #8 端口冲突检测 → #9 去掉 sleep → #10 改善启动检测 → #12 配置文件安全路径
```
