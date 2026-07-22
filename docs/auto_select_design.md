# Velox 自动选择节点设计文档

## 背景

本文档记录了参考 **FlClash + mihomo** 内核，为 Velox 设计并实现自动选择节点功能的完整过程。

---

## 一、mihomo 自动选择三层架构（原型参考）

mihomo 的自动选择由三层结构组成，完整路径为：

```
HealthCheck（调度层） → proxy.URLTest()（测试层） → URLTest.fast()（选择层）
```

### 1. HealthCheck（调度层）
文件：`adapter/provider/healthcheck.go`

| 字段/方法 | 作用 |
|---|---|
| `process()` | Go ticker 定时触发，对标"心跳" |
| `hc.lazy` | Lazy 模式：若 `lastTouch > interval` 则跳过测速 |
| `hc.touch()` | 有 VPN 流量时调用，更新 `lastTouch` |
| `singleDo` | 防止并发重入，同一时刻只允许一次测速 |
| `errgroup.SetLimit(10)` | 并发上限 10，分批测速 |

### 2. proxy.URLTest()（测试层）
文件：`adapter/adapter.go`

- **发送 HTTP HEAD 请求，流量穿过代理隧道**（不是 TCP socket 直连）
- 存储 `alive` + `history`（最近 10 次延迟队列）
- 死亡节点 `LastDelayForTestUrl` 返回 `0xFFFF`，保证排序永远最后
- 测速完成后通过 **UrlTestHook**（FlClash 定制补丁）立即推送结果

### 3. URLTest.fast()（选择层）
文件：`adapter/outboundgroup/urltest.go`

| 逻辑 | 说明 |
|---|---|
| `singledo` 10 秒缓存 | 10 秒内重复调用直接返回缓存结果 |
| 手动覆盖优先 | `u.selected != ""` 时优先使用手动选中节点 |
| `0xFFFF` 排序 | 死节点延迟为最大值，自动排在最后 |
| Tolerance 容差 | 只有 `currentDelay > bestDelay + tolerance` 才切换 fastNode |
| `ForceSet("")` | 清除手动覆盖，恢复自动 |

### 4. UrlTestHook（FlClash 定制）
FlClash fork 的 mihomo 中新增的推送机制：每测完一个节点立即回调 Flutter 层（对标我们的 `StreamController.broadcast()`）。

---

## 二、Velox 与 mihomo 的核心差异

| 对比维度 | mihomo | Velox |
|---|---|---|
| 测速方式 | HTTP HEAD 穿越代理隧道 | TCP Socket 直连 |
| 测速时机 | 连接前即可测速 | 连接前也能测（TCP），连接后再验证（HTTP） |
| 连接前测速能力 | 完整（代理隧道已建立） | 有限（只能测 TCP 可达性） |
| 内核 | Go（mihomo） | Dart + sing-box（Flutter） |

**Chicken-and-egg 问题**：sing-box 需要先连接节点才能建立代理隧道，建立隧道后才能通过它测速。因此 Velox 只能使用 **TCP Socket 预连接测速**（合理权衡），通过 `VpnBloc._checkConnectivity()` 做连接后验证。

---

## 三、Velox 自动选择实现设计

### 核心数据流

```
NodeBloc 加载节点完成
    ↓
AutoTestService.startPeriodic()        ← 对标 HealthCheck 启动
    ↓
每完成一个节点 emit stream             ← 对标 UrlTestHook
    ↓
NodeBloc._onDelayReceived()
    ↓ 更新 servers 延迟 + 重算 autoNow
    ↓
NodeLoaded.autoNow = pickBest()        ← 对标 URLTest.fast()
    ↓
_triggerAutoConnect() 使用 autoNow

VPN 有流量 → AutoTestService.touch()  ← 对标 hc.touch()
用户手动选节点 → AutoTestService.forceSet(server)   ← 对标 ForceSet(name)
用户恢复自动 → AutoTestService.forceSet(null)        ← 对标 ForceSet("")
```

---

## 四、实现文件清单

### 新建文件

| 文件 | 作用 |
|---|---|
| `lib/core/services/auto_test_service.dart` | 自动测速服务（三层架构主体） |

### 修改文件

| 文件 | 修改内容 |
|---|---|
| `lib/core/constants/app_constants.dart` | 新增 `autoTestInterval=300`、`autoTestTolerance=50` |
| `lib/presentation/blocs/node/node_event.dart` | 新增 `_NodeDelayReceived`（内部事件） |
| `lib/presentation/blocs/node/node_state.dart` | `NodeLoaded` 新增 `autoNow` 字段 |
| `lib/presentation/blocs/node/node_bloc.dart` | 注入 AutoTestService，订阅 delayStream，添加 `_onDelayReceived` 处理器 |
| `lib/di/injection.dart` | 注册 `AutoTestService` 为 lazySingleton，更新 NodeBloc factory |
| `lib/presentation/pages/home/main_page.dart` | VPN 有流量时调用 `touch()`，`_triggerAutoConnect` 优先用 `autoNow` |
| `test/mocks/mock_repositories.dart` | 新增 `MockAutoTestService` |
| `test/presentation/blocs/node_bloc_test.dart` | 更新 NodeBloc 构造参数 |

---

## 五、AutoTestService 关键实现

### _ProxyTestState（对标 internalProxyState）
```dart
class _ProxyTestState {
  bool alive = false;
  final Queue<int> history = Queue<int>(); // 最近10次，对标 queue.New(10)

  int get lastDelay {
    if (!alive || history.isEmpty) return 0xFFFF; // 死节点永远排最后
    return history.last;
  }
}
```

### startPeriodic（对标 HealthCheck.process()）
- 启动时立即执行一轮（`Future.microtask`）
- Lazy 模式：`_lastTouch == null`（从未有流量）→ 跳过周期测速
- `_lastTouch` 距今超过 `interval` → 跳过周期测速

### pickBest（对标 URLTest.fast()）
1. 10 秒缓存
2. 手动覆盖优先（`_selectedOverride`）
3. 遍历找最低延迟（死节点 `0xFFFF` 自动排最后）
4. Tolerance 判断：只有超出容差才切换 `fastNode`

---

## 六、DI 注意事项

- `AutoTestService` 注册为 **lazySingleton**：定时器需跨 NodeBloc 生命周期持续运行
- `NodeBloc` 保持 **registerFactory**：每次创建时注入同一个 AutoTestService 实例
- `NodeBloc.close()` 只取消订阅 + 停止定时器（`stop()`），不调用 `dispose()`，保留 StreamController 供下次 NodeBloc 重新订阅
