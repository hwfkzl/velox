# 自动选择节点重构对话记录

> 本文档记录了 2026-04-01 完整的分析与实现过程，涵盖 FlClash、mihomo 内核深度分析，以及 Velox 自动选择的设计与落地。

---

## 一、FlClash 自动选择深度分析

### 1. 数据结构

**ProxyGroup** (`/lib/models/clash_config.dart`)：
```dart
ProxyGroup {
  name, type (URLTest/Selector/Fallback..),
  url,              // 该组专属测速URL
  interval,         // 测试间隔（毫秒）
  timeout,          // 超时时间
  lazy,             // 是否延迟加载
  maxFailedTimes, tolerance...
}
```

**GroupType 判断核心** (`/lib/enum/enum.dart`)：
```dart
bool get isComputedSelected {
  // URLTest 和 Fallback 都属于"自动选择"类型
  return [GroupType.URLTest, GroupType.Fallback].contains(this);
}
```

**运行时 Group 模型** (`/lib/models/common.dart`)：
- `now`：当前自动选中的代理（由 mihomo 内核填充）
- `testUrl`：该组的测速URL（逐级回退）

---

### 2. 分层架构

```
Flutter UI 层
    ↕ FFI / JSON
Go 核心层（mihomo 封装）
    ↕
mihomo 内核（真正的 URLTest 调度器）
```

---

### 3. 自动选择的两条路径

**路径 A：mihomo 内核自动周期调度（后台）**
- 由 YAML 配置中的 `interval`（秒）控制
- mihomo 自动对组内所有代理执行 URLTest
- 选延迟最小且在 `tolerance` 范围内的节点
- 结果写入 `group.now`，Flutter 层轮询获取

**路径 B：Flutter UI 手动触发（前台）**
```
用户点击测速按钮
  → delayTest()
  → setDelay(value=0)  // UI 显示 loading
  → coreController.getDelay(url, proxyName)
  → Go: handleAsyncTestDelay()
  → proxy.URLTest(ctx, testUrl)  // HTTP GET 实际请求
  → 返回 RTT 毫秒值
  → setDelay(result)  // 更新 DelayDataSource
```

---

### 4. 测速 URL 优先级

| 优先级 | 来源 |
|--------|------|
| 1 | ProxyGroup.url（组内配置） |
| 2 | AppSetting.testUrl（全局配置） |
| 3 | 常量 `defaultTestUrl = https://www.gstatic.com/generate_204` |

---

### 5. 最优节点选择算法

**DelayState 比较逻辑**：
```dart
int get priority {
  if (delay > 0) return 0;  // 有效延迟（最优先）
  if (delay == 0) return 1; // 测试中
  return 2;                  // 超时/未测试
}
```

**真正的自动切换**：由 mihomo 内核根据 URLTest 结果设置 `group.now`，Flutter 只是展示。

---

### 6. 自动选择节点的完整机制

FlClash 的自动选择**完全由 mihomo 内核负责**，分三层：

**第一层：mihomo 内核自主调度**

1. 启动时立即对组内所有节点发起 HTTP 测速
2. 之后每隔 `interval` 秒重复测速
3. 比较所有节点延迟，选出最低延迟节点，写入 `group.now`
4. `tolerance` 容差：当前节点延迟不超出最优节点 `tolerance` ms 时不切换

**第二层：Hook 推送延迟数据到 Flutter**

`hub.go` 注册了一个钩子（FlClash 的定制 patch，vanilla mihomo 没有）：
```go
adapter.UrlTestHook = func(url string, name string, delay uint16) {
    sendMessage(Message{Type: DelayMessage, Data: &Delay{Url, Name, Value}})
}
```
每当 mihomo 内部完成一个节点的测速，立即通过 hook 向 Flutter 推送 `DelayMessage`。

**第三层：Flutter 接收并刷新 UI**

`core_manager.dart`：
```dart
Future<void> onDelay(Delay delay) async {
    appController.setDelay(delay);         // ① 立即更新 UI 延迟数值
    debouncer.call(FunctionTag.updateDelay, () async {
        appController.updateGroupsDebounce(); // ② 5秒防抖后重新拉取代理列表
    }, duration: const Duration(milliseconds: 5000));
}
```

**`now` 字段的流转路径：**
```
mihomo内核
  → URLTest 测速完成，更新 group.now = "延迟最低的节点名"
  → UrlTestHook 回调推送 DelayMessage
  → Flutter: setDelay() 更新延迟显示
  → 5秒后: getProxies() 拉取 ProxiesData（含最新 now）
  → Group.fromJson() 解析 now 字段
  → UI 上显示圆形勾选标记
```

**手动覆盖 vs 恢复自动：**
```go
if proxyName == "" {
    selector.ForceSet(proxyName)  // 清空覆盖，恢复自动选择
} else {
    selector.Set(proxyName)       // 手动指定节点（会验证节点存在）
}
```

> **一句话总结**：FlClash 的自动选择 = mihomo 内核按 `interval` 周期测速 + 选最低延迟写入 `now`，Flutter 通过 UrlTestHook 实时接收延迟推送，再通过 5 秒防抖的 `getProxies()` 刷新展示哪个节点被自动选中。Flutter 自身不做任何节点选择决策。

---

## 二、Velox 现有自动选择分析

### 架构特点：无代理组概念

与 FlClash（mihomo 有原生 URLTest 代理组）不同，velox 基于 **sing-box**，没有代理组概念，只有单个 outbound。自动选择是 **Flutter 层自己实现的贪心算法**。

### 测速实现

**文件**: `lib/data/repositories/server_repository_impl.dart`

用的是 **TCP Socket 连接**，不是 HTTP：
```dart
Future<int?> pingServer(ServerModel server) async {
  final stopwatch = Stopwatch()..start();
  final socket = await Socket.connect(
    server.host!,
    server.port ?? 443,
    timeout: const Duration(milliseconds: 5000),
  );
  stopwatch.stop();
  await socket.close();
  return stopwatch.elapsedMilliseconds;  // 失败返回 -1
}
```

批量测速按**每批最多10个节点**并发。

**触发时机**：只有用户手动点击测速按钮才触发，**没有周期性自动测速**。

### 最优节点选择算法

`lib/presentation/pages/home/main_page.dart`：
```dart
ServerModel? _pickBestServer(List<ServerModel> servers) {
  final withLatency = servers
      .where((s) => s.latency != null && s.latency! >= 0)
      .toList();
  if (withLatency.isNotEmpty) {
    withLatency.sort((a, b) => a.latency!.compareTo(b.latency!));
    return withLatency.first;
  }
  return servers.first;
}
```

**算法极简**：纯贪心，排除失败节点（-1），选剩余最低延迟。没有 tolerance 容差、没有权重、没有负载均衡。

### 自动选择的两条路径

**路径 A：启动时自动连接**
```dart
void _triggerAutoConnect(NodeLoaded state) {
  final server = state.selectedServer ?? _pickBestServer(state.servers);
  context.read<VpnBloc>().add(VpnConnectRequested(server: server));
}
```

**路径 B：节点不通时自动切换**

连接成功后 5 秒内无任何上传/下载流量，则 HTTP GET `generate_204`，非 204 即认为节点不通，触发切换。

### 关键设计缺陷

1. **TCP 测速不等于代理可用性** — Socket 连通不代表节点能正常代理流量
2. **无周期测速** — 延迟数据不自动更新，长时间运行后数据过时
3. **切换依赖5秒空窗** — 连通性检测时间窗口较长
4. **无连通性测速前置** — 自动连接前不先测速，可能直连一个高延迟或宕机节点
5. **降级策略粗糙** — 无延迟数据时选"第一个节点"
6. **手动选择永久生效** — `selectedServer` 设置后没有恢复自动选择的机制

---

## 三、mihomo 真实源码分析

> **重要发现：`UrlTestHook` 根本不在 vanilla mihomo 里。** 它是 FlClash 自己给 mihomo fork 打的补丁。

### mihomo 真实工作流程（三层）

**第一层：`HealthCheck.process()` — 定时调度**（healthcheck.go:44）

```go
ticker := time.NewTicker(hc.interval)
go hc.check()  // 启动立即执行一次

for {
    select {
    case <-ticker.C:
        since := time.Since(hc.lastTouch.Load())
        if !hc.lazy || since < hc.interval {
            hc.check()   // lazy 模式：最近有流量才测，否则跳过
        }
    }
}
```

**关键细节**：
- `lazy=true`（默认）时，如果没有流量流过，**直接跳过本轮测速**，节省资源
- `touch()` 在有实际连接流量时才刷新

**第二层：`proxy.URLTest()` — 实际测速**（adapter.go:166）

```go
// 发 HTTP HEAD 请求，通过代理本身路由
instance, err := p.DialContext(ctx, &addr)   // 通过代理建连
req, _ := http.NewRequest(http.MethodHead, url, nil)
resp, err := client.Do(req)

// 结果存入代理对象内部
state.alive.Store(alive)
state.history.Put(C.DelayHistory{Delay: t})
```

`UnifiedDelay` 模式：发两次请求，用第二次的耗时，更准确反映代理延迟。

死节点 `LastDelayForTestUrl` 返回 `0xFFFF`（uint16 最大值），确保死节点永远排最后。

**第三层：`URLTest.fast()` — 节点选择**（urltest.go:107）

```go
elm, _, _ := u.fastSingle.Do(func() (C.Proxy, error) {
    // 1. 手动覆盖：selected != "" 且节点存活 → 直接用
    if u.selected != "" { ... }

    // 2. 找最低延迟（死节点 0xFFFF 自动排最后）
    for _, proxy := range proxies {
        delay := proxy.LastDelayForTestUrl(u.testUrl)
        if delay < minDelay { fast = proxy; minDelay = delay }
    }

    // 3. tolerance：当前节点 delay > 最优 + 容差 才切换
    if u.fastNode == nil ||
       !u.fastNode.AliveForTestUrl(u.testUrl) ||
       u.fastNode.LastDelayForTestUrl(u.testUrl) > fast.LastDelayForTestUrl(u.testUrl) + u.tolerance {
        u.fastNode = fast
    }
    return u.fastNode, nil
})
```

`fastSingle` 是 `singledo.Single(10s)`，即 **10 秒内结果缓存，不重复计算**。

**手动覆盖恢复**：
```go
func (u *URLTest) ForceSet(name string) {
    u.selected = name
    u.fastSingle.Reset()  // 重置10秒缓存，立即重新选择
}
```

---

## 四、Lazy 模式详解

### mihomo lazy 逻辑

```go
case <-ticker.C:
    since := time.Since(hc.lastTouch.Load())   // 距上次有流量多久了
    if !hc.lazy || since < hc.interval {
        hc.check()   // 有流量 → 正常测
    } else {
        log.Debugln("Skip once health check because we are lazy")
        // 没流量超过一个 interval → 跳过
    }
```

**场景示例**（interval=300s，lazy=true）：

| 用户状态 | 行为 |
|---|---|
| 正在使用 VPN | `lastTouch` 持续刷新，每 5 分钟正常测速 |
| APP 切到后台 | 无流量，`lastTouch` 停止，超过 5 分钟后下次定时器触发时跳过 |
| 重新打开 APP | 流量来了，`touch()` 刷新，测速恢复 |

**设计目的**：省资源。如果用户根本没在用这个代理组，mihomo 不会每隔 5 分钟去真实测所有节点。

### Velox Lazy 设计

```
mihomo                              velox 对应
─────────────────────────────────────────────────
hc.lastTouch                   ←→  AutoTestService._lastTouch
touch() 在流量通过时调用        ←→  VPN stats 有流量时 touch()
lazy && since >= interval       ←→  _lastTouch == null 或距今超 interval
```

---

## 五、TCP Socket 测速 vs HTTP 穿隧道测速

### 大白话比喻

**velox TCP 方式**：打电话问司机"你在吗"——司机在，但车没油也没用。

**mihomo URLTest 方式**：直接让司机送你去目的地——能到才算真的能用。

### 为什么 Velox 不能做 mihomo 那种测法

mihomo 可以，是因为它**自己就是代理内核**，可以随时让某个节点帮它发一个 HTTP 请求。

Velox 用的是 sing-box，sing-box **启动后才有代理隧道**。测速发生在连接之前，隧道还没建好，没法让节点帮你发请求。这就是"鸡生蛋"的问题。

```
mihomo：测速（穿隧道）→ 选最优 → 建连接    ← 预判式
velox：TCP 敲门 → 建连接 → generate_204 → 才知道能不能用  ← 试错式
```

> **结论**：`VpnBloc._checkConnectivity()` 是真正穿过代理隧道的测法，准确度高于 mihomo 的预测，只是它是连上之后才测。这两种方案本质上无法同时做到"准确 + 连接前"。

---

## 六、深度对比：mihomo URLTest vs Velox 现状

| 维度 | mihomo URLTest | Velox 现状 | 差距 |
|---|---|---|---|
| **测速方式** | HTTP HEAD 穿过代理隧道 | TCP Socket 直连端口 | 测的不是同一件事 |
| **调度方式** | ticker 周期 + 启动立即执行 | 仅手动触发 | 无自动化 |
| **Lazy 模式** | 无流量时跳过 | 无 | 后台浪费资源 |
| **结果粒度** | 每节点独立存储 alive + history(10条) | 单个 latency 值 | 无历史、无存活状态 |
| **结果推送** | 存储在代理对象（拉取）+ Hook（推送） | 批量等全部完成再推 | 实时性差 |
| **Tolerance** | 有，防频繁切换 | 无 | 可能抖动 |
| **去重防并发** | 2层：1秒 check + 10秒 select | 1个 isPinging flag | 不完整 |
| **手动覆盖** | Set/ForceSet 分离，空串恢复自动 | selectedServer 无恢复机制 | 手动选后永远不自动 |
| **死节点判断** | alive bool 独立，0xFFFF 排最后 | latency<0 当死节点 | 语义不清晰 |

> **一句话结论**：mihomo 的设计核心是**测速与选择完全解耦**。Velox 目前把三件事混在一次手动触发里，本质上是"没有自动选择，只有手动测速后辅助选择"。

---

## 七、Velox 自动选择设计方案

### 核心思想：在 Flutter 层复刻 mihomo 三层架构

```
mihomo 三层                     velox 对应层
─────────────────────────────────────────────────
HealthCheck（调度）         →   AutoTestService._timer
proxy.URLTest()（测试）     →   AutoTestService._pingOne()
URLTest.fast()（选择）      →   AutoTestService.pickBest()
adapter.UrlTestHook         →   StreamController.broadcast()
group.now                   →   NodeLoaded.autoNow
CoreManager.onDelay()       →   NodeBloc._onDelayReceived()
updateGroupsDebounce(5s)    →   节点按需刷新
ForceSet(name)              →   autoTestService.forceSet(server)
ForceSet("")                →   autoTestService.forceSet(null)
```

### 完整数据流

```
APP 启动
  └→ NodeBloc 加载节点完成
       └→ AutoTestService.startPeriodic()          [对标 HealthCheck 启动]
            └→ 立即执行 runOnce()
                 └→ 并发 _pingOne(每个节点)        [对标 errgroup.SetLimit(10)]
                      └→ 每完成一个 emit stream    [对标 UrlTestHook]
                           └→ NodeBloc._onDelayReceived()
                                └→ 更新 server.latency（立即刷新 UI）
                                └→ pickBest() → 更新 autoNow [对标 group.now]

VPN 有流量
  └→ main_page 监听 VpnBloc stats
       └→ AutoTestService.touch()                  [对标 hc.touch()]

300秒后 timer 触发
  └→ _lastTouch 检查                              [对标 lazy 判断]
  └→ 再次 runOnce()

用户手动选节点
  └→ AutoTestService.forceSet(server)             [对标 ForceSet(name)]
  └→ selectedServer = server

用户恢复自动选择
  └→ AutoTestService.forceSet(null)               [对标 ForceSet("")]
  └→ pickBest() 重新选 autoNow
```

---

## 八、实现文件清单

### 新建文件

**`lib/core/services/auto_test_service.dart`** — 自动测速服务（三层架构主体）

核心类设计：
```dart
class _ProxyTestState {
  bool alive = false;
  final Queue<int> history = Queue<int>(); // 最近10次，对标 queue.New(10)

  int get lastDelay {
    if (!alive || history.isEmpty) return 0xFFFF; // 死节点永远排最后
    return history.last;
  }
}

class DelayResult {
  final int serverId;
  final int latency; // >0 正常(ms)，-1 超时/失败
}

class AutoTestService {
  Timer? _timer;
  DateTime? _lastTouch;          // 对标 hc.lastTouch
  bool _isTesting = false;       // 对标 hc.singleDo 防并发
  final _states = <int, _ProxyTestState>{};
  ServerModel? _fastNode;        // 对标 u.fastNode
  ServerModel? _selectedOverride; // 对标 u.selected
  DateTime? _fastCacheTime;      // 对标 fastSingle 10秒缓存
  final _controller = StreamController<DelayResult>.broadcast();

  Stream<DelayResult> get delayStream => _controller.stream;

  void startPeriodic({...});     // 对标 HealthCheck.process()
  void touch();                  // 对标 hc.touch()
  Future<void> runOnce(...);     // 对标 HealthCheck.execute()
  ServerModel? pickBest(...);    // 对标 URLTest.fast()
  void forceSet(ServerModel?);   // 对标 ForceSet
}
```

### 修改文件

| 文件 | 修改内容 |
|---|---|
| `lib/core/constants/app_constants.dart` | 新增 `autoTestInterval=300`、`autoTestTolerance=50` |
| `lib/presentation/blocs/node/node_event.dart` | 新增 `_NodeDelayReceived`（内部事件，对标 UrlTestHook 回调） |
| `lib/presentation/blocs/node/node_state.dart` | `NodeLoaded` 新增 `autoNow` 字段（对标 FlClash `Group.now`） |
| `lib/presentation/blocs/node/node_bloc.dart` | 注入 AutoTestService，节点加载后启动测速，订阅 delayStream，`_onSelectRequested` 调用 `forceSet` |
| `lib/di/injection.dart` | `AutoTestService` 注册为 `lazySingleton`（定时器需跨 NodeBloc 生命周期）；NodeBloc factory 注入 |
| `lib/presentation/pages/home/main_page.dart` | VPN 有流量 → `touch()`；`_triggerAutoConnect` 优先用 `autoNow` |
| `test/mocks/mock_repositories.dart` | 新增 `MockAutoTestService` |
| `test/presentation/blocs/node_bloc_test.dart` | 更新 NodeBloc 构造参数 |

---

## 九、关键设计决策

### DI 注册策略

- `AutoTestService`：**`registerLazySingleton`** — 定时器需跨 NodeBloc 生命周期持续运行
- `NodeBloc`：保持 **`registerFactory`** — 每次创建时注入同一个 AutoTestService 实例
- `NodeBloc.close()`：只取消 `_delaySubscription` + 调用 `stop()`，**不调用 `dispose()`**，保留 StreamController 供下次 NodeBloc 重新订阅

### autoNow 优先级

```dart
// _triggerAutoConnect 优先级
final server = state.autoNow          // 1. 自动测速选出的最优节点
    ?? state.selectedServer           // 2. 用户手动选的节点
    ?? _pickBestServer(state.servers); // 3. fallback
```

### Lazy 模式实现

```dart
// AutoTestService._timer 回调中
if (_lastTouch == null) return; // 从未有流量 → 跳过周期测速
if (DateTime.now().difference(_lastTouch!).inSeconds >= intervalSeconds) return;
// 初次启动的 microtask 仍然执行，不受 lazy 影响
```

### 唯一无法完全对标的地方

mihomo 的 `proxy.URLTest()` 穿过代理隧道测试，velox 的 TCP Socket 测的是端口连通性。这是架构决定的（sing-box 不提供代理组 URLTest 接口），但不影响整体三层架构和选择逻辑的正确性。

---

## 十、`flutter analyze` 结果

改动后只存在以下两类与本次无关的预存错误：
- `test/presentation/blocs/invite_bloc_test.dart`：missing `authRepository`（预存）
- `test/presentation/pages/login_page_test.dart` 等：引用不存在的 `LocaleBloc`（预存）

本次改动引入的 `autoTestService is required` 错误已通过 `MockAutoTestService` 完全修复。
