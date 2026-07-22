# TUN 模式深度对比分析：Clash Verge vs Velox

> 基于 Clash Verge 2.4.7 源码 + mihomo 1.19.23 内核源码 + Velox 当前实现

---

## 目录

1. [整体架构对比](#1-整体架构对比)
2. [mihomo 内核的 TUN 实现](#2-mihomo-内核的-tun-实现)
3. [TUN 开关切换流程](#3-tun-开关切换流程)
4. [进程生命周期管理](#4-进程生命周期管理)
5. [状态管理](#5-状态管理)
6. [TUN 与系统代理的关系](#6-tun-与系统代理的关系)
7. [权限架构](#7-权限架构)
8. [孤立进程处理](#8-孤立进程处理)
9. [DNS 管理](#9-dns-管理)
10. [已知 Bug 分析](#10-已知-bug-分析)
11. [改造路线图](#11-改造路线图)

---

## 1. 整体架构对比

### Clash Verge 架构

```
UI (React/TypeScript)
    │  Tauri IPC (invoke)
    ▼
Tauri 命令层 (Rust)
    │  Arc<Mutex<State>>
    ▼
CoreManager（有状态单例）
    ├── RunningMode::Sidecar  → CommandChild（持有进程句柄）
    └── RunningMode::Service  → clash-verge-service IPC
                                     │
                                     ▼
                               mihomo 进程（内核）
```

**特点：**
- Rust 端是唯一状态源（单一真相）
- `CommandChild` 直接持有进程句柄，进程死亡时 Rust Drop 语义自动感知
- TUN 切换 = 热重载配置（PUT /configs），进程不重启
- 有 Service / Sidecar 双模式，Service 不可用时自动降级

---

### Velox 当前架构

```
UI (Flutter/Dart)
    │  BLoC Event
    ▼
VpnBloc（Dart，状态源 #1）
    │  await mihomoService.connect()
    ▼
MihomoService（Dart，状态源 #2 ← 问题根因）
    │  MethodChannel
    ▼
SingboxFlutterPlugin（Swift）
    ├── 代理模式 → Process（普通用户启动 mihomo）
    └── TUN 模式  → VeloxHelper（Unix Socket JSON）
                         │  fork()
                         ▼
                   mihomo 进程（root，TUN 模式）
```

**存在的问题：**
- **双重状态源**：`VpnBloc.state.status` 和 `MihomoService._currentStatus` 通过异步事件流同步，存在时间差
- TUN 切换触发完整重启，而非热重载
- VeloxHelper 无状态，进程 PID 依赖临时文件跨进程传递（不可靠）

---

## 2. mihomo 内核的 TUN 实现

mihomo 内核**自带完整的 TUN 实现**，底层使用 `sing-tun` 库（SagerNet 出品）。

### 核心文件（mihomo-1.19.23）

```
listener/sing_tun/
├── server.go              ← TUN 服务主实现
├── server_notwindows.go   ← macOS/Linux 路径
├── tun_name_darwin.go     ← macOS utun 设备管理
├── dns.go                 ← DNS 劫持（fake-ip 核心逻辑）
├── iface.go               ← 网络接口管理
└── prepare.go             ← 启动前权限检查

listener/config/tun.go     ← TUN 配置结构体
constant/tun.go            ← Stack 枚举
```

### TUN Stack 类型

```go
// constant/tun.go
const (
    TunGvisor TunStack = iota  // gVisor 用户态网络栈（性能略低，兼容性好）
    TunSystem                  // 系统内核网络栈（性能高，需要更多权限）
    TunMixed                   // 混合模式
)
```

### macOS 上的 TUN 工作原理

```
mihomo（以 root 运行）
    │
    ├── 创建 utun 虚拟网卡（需要 root）
    ├── 设置路由表（所有流量 → utun）
    ├── fake-ip DNS 劫持（53端口）
    │
    ▼
所有 TCP/UDP 流量 → utun → mihomo 处理 → 代理出站
```

**关键结论：TUN 的所有核心逻辑（utun 创建、路由设置、fake-ip、DNS 劫持）mihomo 内核已经全部实现。VeloxHelper 的职责只是以 root 身份启动 mihomo 进程。**

### YAML 配置控制 TUN

mihomo 通过 YAML 配置中的 `tun` 节来控制 TUN 行为：

```yaml
tun:
  enable: true           # ← 这个字段决定是否启用 TUN
  stack: system          # gVisor / system / mixed
  auto-route: true
  auto-detect-interface: true
  dns-hijack:
    - "any:53"

dns:
  enable: true
  enhanced-mode: fake-ip  # TUN 模式必须用 fake-ip
  fake-ip-range: "198.18.0.1/16"
```

**切换 TUN 只需修改 `tun.enable` 字段，然后热重载配置。**

---

## 3. TUN 开关切换流程

### Clash Verge 的做法（行业标准）

```
用户切换 TUN 开关
    │
    ▼
patch_verge({ enable_tun_mode: false })
    │
    ▼
use_tun(config, enable=false)    ← 仅修改配置中的 tun.enable 字段
    │
    ▼
Config::generate()               ← 重新生成运行时 YAML
    │
    ▼
PUT /configs?force=true          ← Mihomo API 热重载（mihomo 进程不重启）
    │
    ├── 成功 → 完成，代理/TUN 全程不中断
    └── 失败 → restart_core() 兜底（完整重启）
```

**mihomo 进程不重启，系统代理不中断，切换延迟 < 100ms。**

---

### Velox 当前的做法（存在问题）

```
用户切换 TUN 开关
    │
    ▼
_toggleTun(false)
    │  保存 proxyMode 到 SharedPreferences
    ▼
VpnConnectRequested(forceReconnect: true)   ← 触发完整重连
    │
    ▼
MihomoService.connect()
    │
    │  BUG: _currentStatus == connected → 提前返回！
    │  修复后：继续执行
    ▼
fullRestartConnect()
    │
    ├── stopMihomo()              ← 停止当前 mihomo（阻塞最多 2s）
    ├── kill_all_mihomo()         ← 清理孤立进程（阻塞最多 2s）
    ├── Thread.sleep(0.5)
    └── startMihomoAsProcess()    ← 启动新 mihomo（等待 2s）
    
总耗时：4-6 秒，全程代理中断
```

**差距：应该走热重载路径，而不是完整重启。**

---

### Velox 应该的做法

```
用户切换 TUN 开关
    │
    ▼
保存设置到 SharedPreferences
    │
    ▼
生成新的 YAML 配置（tun.enable 改为 false）
    │
    ▼
PUT http://127.0.0.1:19090/configs?force=true
    │
    ├── 成功 → 更新系统代理设置（如需要） → 发出 connected 状态
    └── 失败 → 回退到完整重启流程
```

这条路径在 Swift 代码里已经有基础（`hotReloadAndSwitch`），只需扩展支持 TUN 切换。

---

## 4. 进程生命周期管理

### Clash Verge：Arc<CommandChild> 持有句柄

```rust
// CoreManager::State
child_sidecar: ArcSwapOption<CommandChild>

// 停止时
pub(super) fn stop_core_by_sidecar(&self) {
    if let Some(child) = self.take_child_sidecar() {
        let _ = child.kill();  // 直接通过句柄 kill，不需要 PID
    }
}

// 进程意外退出时
// CommandEvent::Terminated 事件自动触发，通过 rx 接收
```

**特点：**
- 持有进程句柄，进程死亡时立即感知
- App 退出时 `Drop` 语义自动清理
- **不需要 PID 文件，不会产生孤立进程**

---

### VeloxHelper 当前设计（无状态）

```c
// start_tun：fork 子进程，只把 PID 写入文件
pid_t pid = fork();
if (pid == 0) {
    execv(singbox, args);  // 子进程执行 mihomo
}
// 父进程（Helper）写 PID 文件后就不管了
FILE *pf = fopen(pid_file, "w");
fprintf(pf, "%d\n", (int)pid);
```

**问题：**
- Helper fork 了 mihomo，但之后对子进程完全失去跟踪
- Helper 重启或子进程意外退出，没有任何通知机制
- PID 文件是跨进程、跨重启的共享状态，极易出错

---

### VeloxHelper 应该的设计（有状态守护进程）

```c
// 全局变量：Helper 进程内持久，LaunchDaemon 长期运行不会丢失
static pid_t g_tun_pid = -1;

// SIGCHLD 处理：子进程退出时自动感知
static void on_child_exit(int sig) {
    int status;
    pid_t dead = waitpid(-1, &status, WNOHANG);
    if (dead == g_tun_pid) {
        fprintf(stderr, "VeloxHelper: mihomo PID=%d exited\n", dead);
        g_tun_pid = -1;
        // 可扩展：通知 App（通过回调 socket 或状态文件）
    }
}

// start_tun：原子替换（先停旧，再启新）
if (strcmp(cmd, "start_tun") == 0) {
    // 先停已有进程
    if (g_tun_pid > 0) {
        kill(g_tun_pid, SIGTERM);
        waitpid(g_tun_pid, NULL, 0);  // 同步等待完全退出
        g_tun_pid = -1;
    }
    // 再启新进程
    pid_t pid = fork();
    if (pid > 0) {
        g_tun_pid = pid;  // 记录到全局变量，不需要 PID 文件
    }
}

// stop_tun：通过全局变量（可选：也接受外部 PID 参数兜底）
if (strcmp(cmd, "stop_tun") == 0) {
    pid_t target = (g_tun_pid > 0) ? g_tun_pid : external_pid;
    if (target > 0) {
        kill(target, SIGTERM);
        waitpid(target, NULL, 0);
        g_tun_pid = -1;
    }
}
```

**优势：**
- 不需要 PID 文件
- 不需要 `kill_all_mihomo`（暴力方案）
- `start_tun` 内部保证原子替换，绝不产生孤立进程
- SIGCHLD 处理可以检测意外崩溃

---

## 5. 状态管理

### Clash Verge：单一状态源

```
Rust 后端（唯一真相）
    │  Tauri Event / SWR 轮询
    ▼
前端 React（只读，不持有独立状态）
```

前端通过 SWR（每 30s 轮询）或 Tauri 事件被动更新，不存在"两个层各自认为自己是真相"的问题。

---

### Velox：双重状态源（Bug 根因）

```
MihomoService._currentStatus    ← Swift 事件异步更新
        ≠（存在时间差）
VpnBloc.state.status            ← BLoC 本地状态
```

**Bug 复现路径：**

```
1. VPN 已连接（TUN 模式）
   MihomoService._currentStatus = connected
   VpnBloc.state.status = VpnStatus.connected

2. 用户关闭 TUN 开关
   _toggleTun(false) → VpnConnectRequested(forceReconnect: true)

3. VpnBloc._onConnectRequested:
   emit(VpnStatus.connecting)  ← BLoC 状态更新
   await _mihomoService.connect(...)  ← 调用服务层

4. MihomoService.connect():
   if (_currentStatus == MihomoStatus.connected) return  ← 直接返回！
   // Swift connect() 从未被调用
   // sendStatus("connected") 永远不会发出

5. VpnBloc 等待流事件 "connected"，但这个事件永远不来
   UI 永远显示 "连接中..."
```

**修复方案（已应用）：**

```dart
// 修复前
if (_currentStatus == MihomoStatus.connecting ||
    _currentStatus == MihomoStatus.connected) {
    return;
}

// 修复后：只拦截并发请求，允许已连接时的 forceReconnect
if (_currentStatus == MihomoStatus.connecting) {
    return;
}
```

**根本解决方案：** 删除 `MihomoService._currentStatus` 这个第二状态源，所有状态变更完全以 Swift 事件为准，VpnBloc 只依赖事件流更新状态。

---

## 6. TUN 与系统代理的关系

### Clash Verge：完全正交独立

```
┌─────────────────────────────────────┐
│  代理捕获方式（互斥）                 │
│  ○ TUN 模式    ← enable_tun_mode     │
│  ○ 系统代理    ← enable_system_proxy │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  流量路由策略（独立）                 │
│  ○ 规则模式 (rule)                   │
│  ○ 全局模式 (global)                 │
│  ○ 直连模式 (direct)                 │
└─────────────────────────────────────┘
```

- 两个开关可以独立切换，互不影响
- TUN 模式和系统代理同时开启是合法状态（TUN 优先）
- 切换任何一个开关都不会影响另一个

```rust
// src-tauri/src/enhance/tun.rs
pub fn use_tun(mut config: Mapping, enable: bool) -> Mapping {
    revise!(tun_val, "enable", enable);  // 只修改 tun.enable
    revise!(config, "tun", tun_val);
    config
    // 系统代理完全不受影响
}
```

---

### Velox 当前设计（存在耦合）

```
proxyMode: 'tun' | 'rule' | 'global' | 'direct'
```

TUN 模式被编码为 `proxyMode` 的一个值，而不是独立的维度。这导致：

- 切换 TUN 必须通过 `VpnConnectRequested` 重新连接
- `lastProxyMode` 需要额外保存"关闭 TUN 后恢复的路由模式"
- 逻辑复杂，容易出错

**建议改为双维度设计：**

```dart
// 独立的两个维度
bool tunEnabled;                           // 是否使用 TUN 捕获
String routingMode;  // 'rule' | 'global' | 'direct'  // 路由策略
```

---

## 7. 权限架构

### Clash Verge

| 模式 | 实现方式 | 权限 |
|------|---------|------|
| Sidecar | Tauri `CommandChild` | 普通用户（无 TUN） |
| Service | `clash-verge-service` LaunchDaemon | root（TUN 模式） |
| 安装 Service | `osascript` + `sudo` shell | 需要一次性管理员授权 |
| DNS 设置 | bash 脚本（set_dns.sh） | 通过 Service |
| 降级策略 | Service 不可用 → 自动 Sidecar | 透明降级 |

---

### Velox

| 模式 | 实现方式 | 权限 |
|------|---------|------|
| 代理模式 | Swift `Process` | 普通用户 |
| TUN 模式 | VeloxHelper LaunchDaemon | root |
| 安装 Helper | `AuthorizationServices` API | 需要一次性管理员授权 |
| DNS 设置 | **缺失** | N/A |
| 降级策略 | **无，直接报错** | N/A |

**Velox 缺少的能力：**
- TUN 模式下的 DNS 管理（设置/恢复系统 DNS）
- Helper 不可用时的降级策略

---

## 8. 孤立进程处理

### Clash Verge：根本不会产生孤立进程

```rust
// App 退出流程
async fn clean_async() {
    CoreManager::global().stop_core().await;
    // stop_core → stop_core_by_sidecar → child.kill()
    // CommandChild Drop 时会 kill 子进程
}
```

通过持有 `CommandChild` 句柄，App 正常退出和异常崩溃都能清理子进程（Rust 析构函数）。

---

### Velox 孤立进程的产生原因

```
场景：App 意外崩溃 / 强制 kill App

→ Swift SingboxFlutterPlugin 未执行清理
→ mihomo 进程（root）继续运行
→ 下次启动时，PID 文件可能记录的是错误的 PID
→ cleanupOrphanedTun() 用错误 PID 发送 stop_tun 无效
→ 真实的孤立 mihomo 持有 port 10808
→ 新 mihomo 启动失败：bind: address already in use
→ UI 卡死在"连接中..."
```

### 已应用的修复（临时方案）

```c
// VeloxHelper.c：kill_all_mihomo 命令
FILE *fp = popen("/usr/bin/pgrep -x mihomo", "r");
// SIGTERM → 等待 2s → SIGKILL
```

**问题：** 可能误杀用户其他 Clash 应用的 mihomo 进程。

### 正确方案（应该改造的）

见 [第4节：VeloxHelper 有状态设计](#4-进程生命周期管理)，通过全局 `g_tun_pid` 从根本上避免孤立进程。

---

## 9. DNS 管理

### Clash Verge（完整实现）

```rust
// src-tauri/src/enhance/tun.rs
if enable {
    // TUN 启用时设置系统 DNS，防止 DNS 泄漏
    AsyncHandler::spawn(move || async move {
        restore_public_dns().await;
        set_public_dns("114.114.114.114".to_string()).await;
    });
} else {
    // TUN 禁用时恢复系统 DNS
    AsyncHandler::spawn(move || async move {
        restore_public_dns().await;
    });
}
```

```bash
# set_dns.sh（macOS）
networksetup -setdnsservers Wi-Fi $1
networksetup -setdnsservers "USB 10/100/1000 LAN" $1

# unset_dns.sh（macOS）
networksetup -setdnsservers Wi-Fi Empty
networksetup -setdnsservers "USB 10/100/1000 LAN" Empty
```

---

### Velox（缺失）

目前完全没有 DNS 管理逻辑。

**影响：**
- TUN 模式下可能发生 DNS 泄漏（系统 DNS 走明文，绕过 fake-ip）
- mihomo 的 fake-ip 设置可能与系统 DNS 冲突

**建议添加：**

```swift
// SingboxFlutterPlugin.swift
private func setSystemDns(_ server: String) {
    // macOS: networksetup -setdnsservers <interface> <server>
    let interfaces = ["Wi-Fi", "Ethernet", "USB 10/100/1000 LAN"]
    for iface in interfaces {
        _ = runCommand("/usr/sbin/networksetup",
                      arguments: ["-setdnsservers", iface, server])
    }
}

private func restoreSystemDns() {
    let interfaces = ["Wi-Fi", "Ethernet", "USB 10/100/1000 LAN"]
    for iface in interfaces {
        _ = runCommand("/usr/sbin/networksetup",
                      arguments: ["-setdnsservers", iface, "Empty"])
    }
}
```

---

## 10. 已知 Bug 分析

### Bug 1：UI 卡死在"连接中..."（已修复）

| | 详情 |
|--|------|
| **触发条件** | TUN 已连接时，关闭 TUN 开关 |
| **根本原因** | `MihomoService._currentStatus == connected` 时，`connect()` 提前返回，Swift 层从未被调用，`sendStatus("connected")` 永远不发出 |
| **修复方案** | 守卫改为只拦截 `connecting`，允许 `connected` 状态下的重新连接 |
| **文件** | `packages/singbox_flutter/lib/src/mihomo_service.dart:90` |

### Bug 2：孤立 root mihomo 进程（已缓解）

| | 详情 |
|--|------|
| **触发条件** | App 意外崩溃，TUN 模式下的 root mihomo 未被清理 |
| **根本原因** | VeloxHelper 是无状态的，PID 文件可能记录错误 PID；非 root 无法杀死 root 进程 |
| **临时修复** | `kill_all_mihomo` 命令 + `start_tun` 开头自动清理 |
| **正确方案** | VeloxHelper 加全局 `g_tun_pid`，`start_tun` 内原子替换 |
| **文件** | `packages/singbox_flutter/macos/Helper/VeloxHelper.c` |

### Bug 3：mode:global 时显示本地 IP（已修复）

| | 详情 |
|--|------|
| **触发条件** | TUN + 全局模式 |
| **根本原因** | `mode: global` 下 GLOBAL selector 默认选 DIRECT，不走代理 |
| **修复方案** | TUN 模式强制使用 `mode: rule`，PROXY group 排首位选中节点 |
| **文件** | `packages/singbox_flutter/lib/src/mihomo_config_generator.dart` |

### Bug 4：TUN 切换完整重启而非热重载（未修复）

| | 详情 |
|--|------|
| **触发条件** | 切换 TUN 开关（任何状态） |
| **根本原因** | `_toggleTun` 触发 `VpnConnectRequested`，走完整重连流程 |
| **影响** | 切换耗时 4-6 秒，代理全程中断，体验差 |
| **正确方案** | PUT /configs 热重载，不重启进程 |

---

## 11. 改造路线图

### 阶段一：紧急修复（已完成）

- [x] `MihomoService.connect()` 守卫修复（允许 forceReconnect）
- [x] `kill_all_mihomo` VeloxHelper 命令（临时清理孤立进程）
- [x] `start_tun` 开头自动清理（保证端口释放）
- [x] `cleanupOrphanedTun()` 改用 `kill_all_mihomo`

### 阶段二：行业对齐（重要）

- [ ] **TUN 切换走热重载路径**
  - `_toggleTun` 不触发 `VpnConnectRequested`
  - 新增 `patchTunMode(bool)` 方法
  - 生成新 YAML → PUT /configs?force=true
  - 仅在热重载失败时回退到完整重连

- [ ] **VeloxHelper 有状态化**
  - 加全局 `g_tun_pid` 变量
  - `start_tun` 内原子替换（先停旧进程再启新进程）
  - 添加 SIGCHLD 处理，监听子进程崩溃
  - 去掉对 PID 文件的依赖

- [ ] **TUN 模式 DNS 管理**
  - TUN 启用时：`networksetup -setdnsservers ... 114.114.114.114`
  - TUN 禁用时：`networksetup -setdnsservers ... Empty`

### 阶段三：架构升级（长期）

- [ ] **消除双重状态源**
  - 删除 `MihomoService._currentStatus`
  - VpnBloc 状态完全以 Swift 事件流为准

- [ ] **TUN/路由模式正交化**
  - `proxyMode` 只表示路由策略（rule/global/direct）
  - `tunEnabled` 独立字段表示是否使用 TUN 捕获
  - 去掉 `lastProxyMode` 的 workaround

- [ ] **权限降级策略**
  - Helper 不可用时，提示用户但允许非 TUN 代理模式继续工作

---

## 附录：关键文件索引

### Velox 相关

| 文件 | 职责 |
|------|------|
| `packages/singbox_flutter/lib/src/mihomo_service.dart` | MihomoService：Dart 层服务，MethodChannel 封装 |
| `packages/singbox_flutter/lib/src/mihomo_config_generator.dart` | YAML 配置生成（TUN/DNS/路由策略） |
| `packages/singbox_flutter/macos/Classes/SingboxFlutterPlugin.swift` | Swift 插件：进程管理、Helper 通信、状态事件 |
| `packages/singbox_flutter/macos/Helper/VeloxHelper.c` | LaunchDaemon Helper：root 权限操作 |
| `lib/presentation/blocs/vpn/vpn_bloc.dart` | VPN 状态机 |
| `lib/presentation/pages/nodes/nodes_page.dart` | TUN 开关 UI 逻辑 |

### Clash Verge 参考

| 文件 | 职责 |
|------|------|
| `src-tauri/src/enhance/tun.rs` | TUN 配置生成（含 DNS 管理） |
| `src-tauri/src/core/manager/lifecycle.rs` | 进程启动/停止/重启 |
| `src-tauri/src/core/manager/config.rs` | 热重载逻辑（含防抖 300ms） |
| `src-tauri/src/core/sysopt.rs` | 系统代理设置 |
| `src-tauri/src/feat/config.rs` | 配置变更决策树 |
| `src/hooks/use-system-state.ts` | TUN 权限状态检测 |

### mihomo 内核参考

| 文件 | 职责 |
|------|------|
| `listener/sing_tun/server.go` | TUN 服务主实现 |
| `listener/sing_tun/tun_name_darwin.go` | macOS utun 设备 |
| `listener/sing_tun/dns.go` | fake-ip DNS 劫持 |
| `listener/config/tun.go` | TUN 配置结构体 |
| `constant/tun.go` | Stack 类型枚举 |
