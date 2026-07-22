# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目简介

Velox 是一个基于 Flutter 开发的跨平台 VPN 客户端应用，对接 V2Board 后端管理系统。

## 常用命令

```bash
# 安装依赖
flutter pub get

# 代码生成（生成 JSON 序列化代码）
dart run build_runner build --delete-conflicting-outputs

# 运行应用
flutter run                    # 默认设备
flutter run -d chrome          # Web
flutter run -d macos           # macOS
flutter run -d ios             # iOS 模拟器

# 构建
flutter build apk              # Android APK
flutter build ios              # iOS
flutter build macos            # macOS

# 测试
flutter test                   # 运行所有测试
flutter test test/widget_test.dart  # 运行单个测试

# 代码分析
flutter analyze
dart format .
```

## 项目架构

采用 Clean Architecture 分层架构：

```
lib/
├── main.dart                 # 应用入口
├── app/                      # 应用配置
│   ├── app.dart             # 应用根组件
│   └── router.dart          # 路由配置 (go_router)
├── core/                     # 核心模块
│   ├── constants/           # 常量 (API端点、存储键名)
│   ├── errors/              # 异常和失败处理
│   ├── network/             # 网络层 (Dio客户端)
│   ├── storage/             # 存储层 (SecureStorage, SharedPreferences)
│   └── theme/               # 主题 (颜色、样式)
├── data/                     # 数据层
│   ├── datasources/         # 数据源 (remote/local)
│   ├── models/              # 数据模型 (JSON序列化)
│   └── repositories/        # 仓库实现
├── domain/                   # 领域层
│   ├── entities/            # 实体
│   ├── repositories/        # 仓库接口
│   └── usecases/            # 用例
├── presentation/             # 表现层
│   ├── blocs/               # BLoC 状态管理
│   ├── pages/               # 页面
│   └── widgets/             # 组件
├── l10n/                     # 国际化 (简体中文/繁体中文/英语)
└── di/                       # 依赖注入 (get_it)
```

## 技术栈

- **状态管理**: flutter_bloc
- **路由**: go_router
- **网络请求**: dio
- **本地存储**: shared_preferences, flutter_secure_storage, hive
- **依赖注入**: get_it
- **JSON序列化**: json_serializable, freezed

## API 对接

后端使用 V2Board (xiaoV2b 版本)，API 基础地址配置在 `.env` 文件中。

主要 API 端点定义在 `lib/core/constants/api_constants.dart`。

## 多语言支持

支持三种语言（定义在 `lib/l10n/`）：
- 简体中文 (zh) - 默认
- 繁体中文 (zh_TW)
- 英语 (en)

## 开发注意事项

- 敏感信息（Token、密码）存储在 SecureStorage
- 修改数据模型后需运行 `dart run build_runner build`
- 环境配置使用 `.env` 文件（不要提交到 Git）
