# Velox

跨平台 VPN 客户端(Flutter),对接 V2Board 后端 + mihomo(Clash Meta)内核。
支持 Android / iOS / macOS / Windows / Linux。

## 首次 setup(必看)

Clone 之后**不能直接 `flutter build`**,以下 2 个文件被 `.gitignore` 排除,需要手动创建:

```bash
cp .env.example .env
```

编辑 `.env`,至少填入 `OSS_URL`(OSS 上的 host.json 地址,格式见文件内注释)。
Telegram 反馈通道选填(不填 → app 里"上传 debug 日志"按钮 disabled)。

`config.json` **不需要创建** —— app 运行时从 OSS 拉真实业务配置,`config.example.json` 只是给运维看字段结构的参考。

## 环境依赖

| 平台 | 需要 |
|---|---|
| Windows | Flutter 3.38+ · VS 2022 Community + Desktop C++ workload · Windows 10 build 1809+ |
| macOS | Flutter 3.38+ · Xcode 15+ · macOS 12+ |
| Android | Flutter 3.38+ · Android Studio · JDK 17 · Release 签名需 `android/key.properties` + `.jks`(gitignored) |
| iOS | Flutter 3.38+ · Xcode 15+ · `ios/Frameworks/Libbox.xcframework`(1.5 GB,从 [sing-box releases](https://github.com/SagerNet/sing-box/releases) 下载) |

## 常用命令

```bash
flutter pub get                    # 拉依赖
flutter run -d windows             # dev 模式(hot reload,按 r/R)
flutter run -d macos               # 同上
flutter build windows --release    # 出 windows/x64 Release
.\scripts\pack-windows.ps1         # (Windows)build + 打 zip + SHA256
dart run build_runner build --delete-conflicting-outputs   # 生成 json_serializable 代码
```

## 项目结构(Clean Architecture)

```
lib/
├── main.dart                # 入口
├── app/                     # 应用配置(router / theme)
├── core/                    # 常量 / 网络 / 存储 / 主题
├── data/                    # 数据源 / 模型 / repository 实现
├── domain/                  # 实体 / repository 接口 / usecase
├── presentation/            # BLoC / pages / widgets
├── l10n/                    # 简繁英三语
└── di/                      # get_it 依赖注入

packages/singbox_flutter/    # mihomo/singbox native plugin (Windows/macOS/Android/iOS)
```

## 内置二进制

预打包在 repo 里(GitHub 100 MB 单文件限内):

- `packages/singbox_flutter/windows/bin/mihomo.exe`(45 MB)+ `wintun.dll`
- `macos/Resources/mihomo`(64 MB,macOS 通用二进制)
- `assets/geo/geoip.metadb` + `geosite.dat`

详见 `packages/singbox_flutter/windows/bin/README.txt`。

## CI

`.github/workflows/build-windows.yml` —— push 到 `master` 或 `v*` tag 自动跑 Windows build,产物在 Actions 页面 Artifacts:
- `Velox-<ver>-windows-x64-setup.exe`(Inno Setup 安装包)
- `velox-<ver>-windows-x64.zip`(便携版)

## 敏感文件(NEVER commit)

`.gitignore` 已覆盖:
- `.env*` 除 `.env.example`
- iOS 签名(`*.p12`/`*.mobileprovision`/`*.cer`/`*.certSigningRequest`)
- Android 签名(`android/key.properties`, `*.jks`)
- Firebase 配置(`google-services.json` / `GoogleService-Info.plist`)
- 编译产物(`*.dmg` / `*.pkg` / `dist/`)
- `config.json`(含后端 URL)
- Libbox.xcframework(1.5 GB,超 GitHub 限制)
- Xcode `xcuserdata/*.xcuserstate`,Pods,Xcode build cache

## 技术栈

- 状态管理:`flutter_bloc`
- 路由:`go_router`
- 网络:`dio`
- 本地存储:`shared_preferences` / `flutter_secure_storage` / `hive`
- 依赖注入:`get_it`
- 序列化:`json_serializable` / `freezed`
