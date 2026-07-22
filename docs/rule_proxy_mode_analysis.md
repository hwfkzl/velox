# 规则代理模式深度分析

## 一、后端（V2Board）标准配置

后端 `resources/rules/default.clash.yaml` 是行业参考基准，核心结构如下：

### 1.1 DNS 配置（后端标准）

```yaml
dns:
  enable: true
  ipv6: false

  # ① 引导 DNS：用于解析 DoH/DoT 服务器本身的域名（必须是纯 IP，不走代理）
  default-nameserver:
    - 223.5.5.5      # 阿里
    - 119.29.29.29   # 腾讯
    - 114.114.114.114

  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  use-hosts: true
  respect-rules: true   # Mihomo Meta 专有：DNS 查询也遵循 rules，防泄漏

  # ② 代理节点域名解析：用国内 DNS 直连（防节点域名被 fake-ip 化）
  proxy-server-nameserver:
    - 223.5.5.5
    - 119.29.29.29
    - 114.114.114.114

  # ③ 主 DNS：国内优先
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
    - 114.114.114.114

  # ④ Fallback DNS：海外（当 nameserver 被污染时介入）
  fallback:
    - 1.1.1.1
    - 8.8.8.8

  # ⑤ Fallback 触发条件（关键：防 DNS 污染）
  fallback-filter:
    geoip: true
    geoip-code: CN        # nameserver 返回非 CN IP → 触发 fallback
    geosite:
      - gfw               # GFW 屏蔽域名强制走 fallback（海外 DNS）
    ipcidr:
      - 240.0.0.0/4       # 保留地址（明显错误）
    domain:               # 这些域名国内 DNS 一定会污染
      - '+.google.com'
      - '+.facebook.com'
      - '+.youtube.com'
```

### 1.2 Rules 结构（后端标准）

```
优先级（从高到低）:
  1. 代理节点 IP/域名 → DIRECT（防路由回环，最高优先级）
  2. Google/Apple 特定服务 → PROXY（被特殊对待的海外服务）
  3. 大量手写国内域名 → DIRECT（精确匹配，快）
  4. 大量手写海外域名 → PROXY（精确匹配，快）
  5. Telegram IP段 → PROXY（no-resolve，不触发 DNS）
  6. LAN 地址 → DIRECT
  7. GEOIP,CN → DIRECT（兜底：中国 IP 直连）
  8. MATCH → PROXY（最终：其他全走代理）
```

后端规则约 **300+ 条**手写域名，覆盖主流国内/海外服务，GEOSITE/GEOIP 仅作最终兜底。

---

## 二、我们客户端的现状对比

### 2.1 DNS 配置对比

| 配置项 | 后端标准 | 我们的客户端 | 问题 |
|--------|---------|------------|------|
| `default-nameserver` | `[223.5.5.5, 119.29.29.29]` | **缺失** | DoH 服务器域名无法解析 |
| `proxy-server-nameserver` | `[223.5.5.5, ...]` | **缺失** | 节点域名可能被 fake-ip 化，连接失败 |
| `nameserver` | 国内 DNS 为主 | `tls://8.8.8.8`（海外） | 国内网站 CDN 优化失效 |
| `fallback` | `[1.1.1.1, 8.8.8.8]` | 与 nameserver 相同 | fallback 无意义 |
| `fallback-filter` | geoip+geosite+ipcidr+domain | **缺失** | DNS 污染无法过滤 |
| `respect-rules` | `true` | **缺失** | DNS 可能绕过规则泄漏 |
| `fake-ip-filter` | NTP/NCSI/QQ登录 | 仅3条 | NTP/系统网络检测异常 |

### 2.2 Rules 对比

| 配置项 | 后端标准 | 我们的客户端 | 问题 |
|--------|---------|------------|------|
| 规则总数 | 300+ | 约 10 | 大量网站路由依赖 GEOSITE 兜底，性能差 |
| `no-resolve` 覆盖 | IP-CIDR/GEOIP 全加 | 部分缺失 | fake-ip 模式下可能触发多余 DNS |
| `GEOSITE,CN` 顺序 | 在 GEOIP 前 | **在 GEOIP 后** | 多余的 DNS 解析 |
| `GEOIP,private` | 手写 LAN IP-CIDR | 手写 LAN IP-CIDR | 两者等价，后端更完整 |
| Telegram IP | 精确 IP-CIDR + no-resolve | 无 | Telegram 走了不必要的 DNS |

### 2.3 Proxy Groups 对比

| Group | 后端标准 | 我们的客户端 |
|-------|---------|------------|
| 主选择器 | `select: [自动选择, 故障转移]` | `select: [proxy-101, ...]` |
| 自动选择 | `url-test`（延迟测试自动选最快） | 无 |
| 故障转移 | `fallback`（主节点挂了自动切换） | 无 |

> 我们是用户手动选节点的 VPN 客户端，不需要自动选择/故障转移 group，但 DNS 和规则质量应达到后端标准。

---

## 三、行业标准 DNS 工作原理

```
用户请求 google.com
         │
         ▼
  fake-ip 模式：直接返回 fake IP（198.18.x.x）
  Mihomo 记录映射：198.18.x.x → google.com
         │
  规则匹配（无需真实 IP）
  GEOSITE,geolocation-!cn → 走 PROXY group
         │
         ▼
  连接代理节点时才做真实 DNS 解析
  （由远端代理服务器解析，避免本地 DNS 污染）
```

```
用户请求 baidu.com
         │
         ▼
  proxy-server-nameserver（国内 DNS）检测到是国内域名
  nameserver 返回 CN IP → fallback-filter 判断：
    geoip=CN → 不触发 fallback → 直接用 nameserver 结果
         │
  规则匹配：GEOSITE,CN → DIRECT
         │
         ▼
  直连 baidu.com（用真实 CN IP）
```

```
用户请求 twitter.com（被污染域名）
         │
         ▼
  nameserver（国内 DNS）返回 污染IP
  fallback-filter 判断：
    - geosite:gfw 命中 → 触发 fallback
    - 或 geoip 非 CN IP → 触发 fallback
  fallback（1.1.1.1）返回 真实 IP
         │
  规则匹配：MATCH → PROXY
```

---

## 四、我们客户端的修复方案

### 4.1 DNS 修复（已实施）

```yaml
# 修复后的 rule 模式 DNS
dns:
  enable: true
  ipv6: false
  
  # 新增：引导 DNS（纯 IP，用于解析 DoH 服务器域名）
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  respect-rules: true    # 新增
  
  # 新增：fake-ip 豁免列表
  fake-ip-filter:
    - '*.lan'
    - '*.local'
    - '*.localhost'
    - '*.arpa'
    - 'time.*.com'       # NTP
    - 'ntp.*.com'        # NTP
    - 'time.apple.com'
    - '*.msftncsi.com'   # Windows 网络检测
    - 'www.msftconnecttest.com'
    - 'localhost.ptlogin2.qq.com'
    - '+.stun.*.*'       # WebRTC STUN
    - '+.stun.*.*.*'
  
  # 修复：主 DNS 改为国内
  nameserver:
    - https://dns.alidns.com/dns-query   # 阿里 DoH
    - https://doh.pub/dns-query          # 腾讯 DoH
  
  # 修复：fallback 改为海外
  fallback:
    - https://1.1.1.1/dns-query
    - https://8.8.8.8/dns-query
  
  # 新增：DNS 污染防护
  fallback-filter:
    geoip: true
    geoip-code: CN
    geosite:
      - gfw
    ipcidr:
      - 240.0.0.0/4
      - 0.0.0.0/32
    domain:
      - '+.google.com'
      - '+.facebook.com'
      - '+.youtube.com'
      - '+.twitter.com'
      - '+.github.com'
  
  # 新增：节点域名用国内 DNS 解析
  proxy-server-nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
  
  # 新增：分域名解析策略
  nameserver-policy:
    'geosite:cn,private':
      - https://dns.alidns.com/dns-query
      - https://doh.pub/dns-query
    'geosite:geolocation-!cn':
      - https://1.1.1.1/dns-query
      - https://8.8.8.8/dns-query
```

### 4.2 Rules 修复（已实施）

```yaml
rules:
  # 节点 IP 直连（no-resolve：fake-ip 模式下不触发 DNS）
  - IP-CIDR,x.x.x.x/32,DIRECT,no-resolve
  
  # 私有地址（新增 no-resolve）
  - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
  - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
  - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve
  - IP-CIDR,169.254.0.0/16,DIRECT,no-resolve
  
  # 顺序修复：GEOSITE 在 GEOIP 前（域名规则不需要 DNS 解析，更快）
  - GEOSITE,CN,DIRECT
  
  # 中国 IP（新增 no-resolve）
  - GEOIP,CN,DIRECT,no-resolve
  
  - MATCH,PROXY
```

### 4.3 对比修复前后

```
修复前（rule 模式）：
  访问 google.com → nameserver 8.8.8.8 解析 → 规则匹配 GEOIP,CN → MATCH,PROXY ✓
  访问 baidu.com  → nameserver 8.8.8.8 解析（海外 DNS 解析国内域名！）→ CDN 节点差

修复后（rule 模式）：
  访问 google.com → fake-ip → geosite:geolocation-!cn → 1.1.1.1 解析 → MATCH,PROXY ✓
  访问 baidu.com  → fake-ip → geosite:cn → alidns 解析（最优 CDN）→ GEOSITE,CN,DIRECT ✓
  访问 twitter.com → fake-ip → alidns 被污染 → fallback-filter 触发 → 1.1.1.1 ✓
```

---

## 五、与后端的剩余差距

| 项目 | 后端 | 我们（修复后） | 说明 |
|------|------|-------------|------|
| 手写域名规则 | 300+ | 0 | 靠 GEOSITE 兜底，可接受 |
| Telegram IP 规则 | 精确 IP-CIDR | 无 | Telegram 走 MATCH,PROXY 兜底 |
| Apple 服务精细控制 | 部分 DIRECT/代理 | 无 | iCloud 等走 MATCH 兜底 |
| 广告屏蔽 | REJECT 规则 | 无 | 不在 VPN 客户端职责范围 |
| url-test 自动选择 | 有 | 无 | 我们是手动选节点 |
| `use-hosts: true` | 有 | 无 | 低优先级 |

**结论**：手写 300 条规则的方式是旧时代产物，现代做法（Mihomo Meta v1.18+）用 `GEOSITE:CN` + `fallback-filter: geosite: gfw` 的组合完全可以替代，且准确性更高（GEOSITE 数据库每天更新）。我们的修复方案在 DNS 质量上已达到或超过后端标准，规则简洁度也更优。
