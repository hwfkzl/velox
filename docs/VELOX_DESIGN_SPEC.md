# Velox VPN - Flutter UI 设计规范

## 项目概述

Velox 是一款 VPN 客户端应用，需要使用 Flutter 开发 iOS 和 Android 双端。设计风格为深色主题 + 冰蓝色系，整体视觉现代、简洁、具有安全感。

---

## 色彩系统

```dart
class VeloxColors {
  // 主色调
  static const Color primary = Color(0xFF38BDF8);        // 冰蓝色
  static const Color primaryDark = Color(0xFF0EA5E9);    // 深冰蓝
  static const Color primaryDarker = Color(0xFF0369A1);  // 更深冰蓝
  
  // 背景色
  static const Color bgPrimary = Color(0xFF0F172A);      // 主背景
  static const Color bgSecondary = Color(0xFF020617);    // 次背景
  static const Color bgCard = Color(0xFF1E293B);         // 卡片背景
  static const Color bgInput = Color(0xFF0F172A);        // 输入框背景
  
  // 文字色
  static const Color textPrimary = Color(0xFFF1F5F9);    // 主文字
  static const Color textSecondary = Color(0xFF94A3B8);  // 次文字
  static const Color textTertiary = Color(0xFF64748B);   // 辅助文字
  
  // 功能色
  static const Color success = Color(0xFF4ADE80);        // 成功/已连接
  static const Color warning = Color(0xFFFBBF24);        // 警告/中等负载
  static const Color error = Color(0xFFF87171);          // 错误/高负载
  
  // 边框色
  static const Color border = Color(0xFF475569);         // 默认边框
  static const Color borderLight = Color(0x4D475569);    // 浅色边框 (30% opacity)
  static const Color borderPrimary = Color(0x6638BDF8);  // 主色边框 (40% opacity)
}
```

---

## 字体规范

```dart
class VeloxTextStyles {
  // 标题
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: VeloxColors.textPrimary,
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: VeloxColors.textPrimary,
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: VeloxColors.textPrimary,
  );
  
  // 正文
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: VeloxColors.textPrimary,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: VeloxColors.textSecondary,
  );
  
  // 辅助
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: VeloxColors.textTertiary,
  );
  
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}
```

---

## 间距与圆角

```dart
class VeloxSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  
  // 页面边距
  static const double pagePadding = 24;
}

class VeloxRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 20;
  static const double round = 100;  // 圆形按钮
}
```

---

## 页面结构

### 1. 启动流程页面

#### 1.1 启动页 (SplashScreen)
- Logo 居中显示，带发光动画效果
- 品牌名称 "VELOX" 使用渐变色
- 底部有 "开始使用" 按钮
- 背景为深色渐变

#### 1.2 引导页 (OnboardingScreen)
- 3 个步骤的轮播介绍
- 每步包含：大图标、标题、描述文字
- 底部有进度指示点和导航按钮
- 内容：
  - 步骤1: 🛡️ 军事级加密 - AES-256 加密技术
  - 步骤2: ⚡ 极速体验 - 全球优质节点
  - 步骤3: 🌍 全球覆盖 - 50+ 国家 200+ 服务器

#### 1.3 登录页 (LoginScreen)
- 顶部 Logo + 欢迎文字
- 邮箱输入框
- 密码输入框
- 忘记密码链接
- 登录按钮（主色渐变）
- 分隔线 "或"
- 手机验证码登录按钮
- 扫码导入订阅按钮
- 底部注册链接

#### 1.4 注册页 (RegisterScreen)
- 返回按钮
- 标题 "创建账户"
- 邮箱输入框
- 验证码输入框 + 获取验证码按钮
- 设置密码输入框
- 确认密码输入框
- 邀请码输入框（选填）
- 注册按钮
- 服务条款和隐私政策链接

#### 1.5 扫码导入页 (QRImportScreen)
- 返回按钮
- 标题 "扫描二维码"
- 相机取景框（四角装饰 + 扫描线动画）
- 底部功能按钮：相册、闪光灯、链接导入

#### 1.6 链接导入页 (URLImportScreen)
- 返回按钮
- 标题 "订阅链接导入"
- 多行文本输入框
- 从剪贴板粘贴按钮
- 提示卡片（说明订阅链接获取方式）
- 导入订阅按钮

---

### 2. 核心功能页面（带底部导航）

#### 2.1 首页 (HomeScreen)
- 顶部 Logo
- 连接状态指示（绿色圆点 + 文字）
- 中央大圆形连接按钮
  - 未连接：蓝色渐变 + ⚡图标 + "连接"
  - 连接中：显示加载 + 外圈脉冲动画
  - 已连接：绿色渐变 + 🛡️图标 + "断开"
- 当前节点卡片（国旗 + 名称 + 延迟）
- 已连接时显示：实时上传/下载速度卡片

#### 2.2 节点列表页 (ServersScreen)
- 标题 "选择节点"
- 区域筛选标签（全部/亚洲/美洲/欧洲）
- 智能选择按钮（蓝色渐变，带 ✨ 图标）
- 节点列表，每项显示：
  - 国旗 Emoji
  - 节点名称
  - 负载进度条（绿/黄/红）
  - 延迟数值（颜色编码：<50ms绿色，<150ms黄色，>150ms红色）

#### 2.3 流量统计页 (StatsScreen)
- 标题 "流量统计"
- 用量卡片：
  - 环形进度图显示使用百分比
  - 已用流量 / 总流量
  - 重置倒计时
- 四宫格统计：今日下载、今日上传、连接时长、连接次数
- 7日流量趋势柱状图

#### 2.4 订阅页 (SubscriptionScreen)
- 用户头像 + 邮箱 + 会员等级标签
- 当前套餐卡片：
  - 套餐名称
  - 价格和流量
  - 到期时间和剩余天数
- 续费订阅按钮
- 功能入口列表：
  - 订阅链接
  - 二维码
  - 使用记录
  - 邀请返利

#### 2.5 设置页 (SettingsScreen)
- 标题 "设置"
- 连接设置组：协议选择、分应用代理、自动连接、Kill Switch
- 通用设置组：深色模式、语言、通知
- 支持组：帮助中心、联系客服、用户协议、关于我们
- 退出登录按钮（红色）
- 版本号

---

### 3. 订阅相关子页面

#### 3.1 套餐选择页 (PlansScreen)
- 返回按钮
- 标题 "选择套餐"
- 三个套餐卡片（可选中状态）：
  - 月付：¥29/月，50GB，2设备
  - 季付：¥69/季，80GB/月，3设备（标记"最受欢迎"）
  - 年付：¥199/年，100GB/月，5设备，专属客服
- 立即购买按钮

#### 3.2 订阅链接页 (SubLinkScreen)
- 返回按钮
- 标题 "订阅链接"
- 链接文本框（monospace 字体）
- 复制链接 + 刷新按钮
- 一键导入卡片（支持 Clash、V2RayN、Shadowrocket、Quantumult X）

#### 3.3 订阅二维码页 (SubQRScreen)
- 返回按钮
- 标题 "订阅二维码"
- 白底二维码图片
- 保存图片 + 分享按钮

#### 3.4 使用记录页 (LogsScreen)
- 返回按钮
- 标题 "使用记录"
- 日志列表，每项显示：
  - 状态点（绿/灰/红）
  - 状态文字（已连接/已断开/连接失败）
  - 时间
  - 服务器名称
  - 连接时长

#### 3.5 邀请返利页 (InviteScreen)
- 返回按钮
- 标题 "邀请返利"
- 统计卡片：已获佣金、已邀请人数
- 邀请码卡片（大字显示 + 复制按钮）
- 邀请规则说明
- 分享给好友按钮

---

### 4. 设置相关子页面

#### 4.1 分应用代理页 (SplitTunnelScreen)
- 返回按钮
- 标题 "分应用代理"
- 模式选择：仅代理选中 / 绕过选中
- 应用列表，每项带开关控件
- 预设应用：Chrome、YouTube、Twitter、Telegram、微信、支付宝、抖音、Netflix、Spotify、Steam

#### 4.2 协议选择页 (ProtocolScreen)
- 返回按钮
- 标题 "协议选择"
- 协议列表（单选）：
  - VMess - 主流协议，兼容性好（推荐标签）
  - VLESS - 轻量高效，性能优秀
  - Trojan - 高度伪装，安全性强
  - Shadowsocks - 经典协议，稳定可靠

#### 4.3 帮助中心页 (HelpScreen)
- 返回按钮
- 标题 "帮助中心"
- FAQ 列表（Q&A 格式）
- 联系在线客服按钮

---

## 底部导航栏

固定在底部，包含 5 个入口：
1. ⚡ 首页
2. 🌐 节点
3. 📊 统计
4. 👤 订阅
5. ⚙️ 设置

选中态：图标和文字变为主色（#38BDF8）
未选中态：图标和文字为灰色（#64748B）

---

## 通用组件

### 主按钮 (PrimaryButton)
- 背景：蓝色渐变 (primary → primaryDarker)
- 圆角：14px
- 高度：56px
- 文字：16px 白色加粗
- 阴影：蓝色光晕

### 次级按钮 (SecondaryButton)
- 背景：透明或深色
- 边框：1px 主色 40% 透明度
- 文字：主色

### 输入框 (TextField)
- 背景：#0F172A 80% 透明度
- 边框：1px #475569 50% 透明度
- 圆角：12px
- 高度：56px
- 文字：15px 白色

### 卡片 (Card)
- 背景：#1E293B 或渐变
- 边框：1px 主色 20% 透明度
- 圆角：16-20px
- 内边距：20-24px

### 列表项 (ListTile)
- 背景：#0F172A 60% 透明度
- 边框：1px #475569 30% 透明度
- 圆角：12px
- 高度：约 56px
- 内边距：14-16px

---

## 动画效果

1. **连接按钮脉冲**：连接中时外圈缩放动画
2. **扫码线**：上下循环移动
3. **Logo 发光**：呼吸灯效果
4. **页面切换**：淡入 + 上滑
5. **开关切换**：滑块平滑移动

---

## 推荐依赖

```yaml
dependencies:
  flutter_riverpod: ^2.4.0      # 状态管理
  go_router: ^12.0.0            # 路由
  fl_chart: ^0.65.0             # 图表
  flutter_animate: ^4.3.0       # 动画
  mobile_scanner: ^3.5.0        # 二维码扫描
  flutter_svg: ^2.0.0           # SVG 图标
  shared_preferences: ^2.2.0    # 本地存储
  dio: ^5.3.0                   # 网络请求
  qr_flutter: ^4.1.0            # 二维码生成
```

---

## 目录结构建议

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── theme/
│   │   ├── colors.dart
│   │   ├── text_styles.dart
│   │   └── theme.dart
│   ├── constants/
│   │   └── app_constants.dart
│   └── router/
│       └── app_router.dart
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── onboarding_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── qr_import_screen.dart
│   │   │   └── url_import_screen.dart
│   │   └── widgets/
│   ├── home/
│   │   ├── screens/
│   │   │   └── home_screen.dart
│   │   └── widgets/
│   │       └── connect_button.dart
│   ├── servers/
│   │   ├── screens/
│   │   │   └── servers_screen.dart
│   │   └── widgets/
│   │       └── server_tile.dart
│   ├── stats/
│   │   ├── screens/
│   │   │   └── stats_screen.dart
│   │   └── widgets/
│   ├── subscription/
│   │   ├── screens/
│   │   │   ├── subscription_screen.dart
│   │   │   ├── plans_screen.dart
│   │   │   ├── sub_link_screen.dart
│   │   │   ├── sub_qr_screen.dart
│   │   │   ├── logs_screen.dart
│   │   │   └── invite_screen.dart
│   │   └── widgets/
│   └── settings/
│       ├── screens/
│       │   ├── settings_screen.dart
│       │   ├── split_tunnel_screen.dart
│       │   ├── protocol_screen.dart
│       │   └── help_screen.dart
│       └── widgets/
└── shared/
    ├── widgets/
    │   ├── primary_button.dart
    │   ├── secondary_button.dart
    │   ├── custom_text_field.dart
    │   ├── app_card.dart
    │   └── bottom_nav_bar.dart
    └── models/
        ├── server.dart
        ├── user.dart
        └── subscription.dart
```
