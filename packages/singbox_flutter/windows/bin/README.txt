mihomo (Clash Meta) Windows binary drop-in
==========================================

在 Windows 构建之前，把 mihomo 内核放到这个目录并重命名为 mihomo.exe：

  packages/singbox_flutter/windows/bin/mihomo.exe

下载：
  https://github.com/MetaCubeX/mihomo/releases

  x64 主流：mihomo-windows-amd64-vX.Y.Z.zip 解压后重命名 → mihomo.exe
  arm64（可选）：mihomo-windows-arm64-vX.Y.Z.zip → mihomo.exe

CMakeLists.txt 里通过 singbox_flutter_bundled_libraries 把此文件登记为随插件分发，
flutter build windows --release 会自动把它 copy 到 build/windows/x64/runner/Release/。

.gitignore 已忽略 *.exe；如需 CI 拉取，用 GH release / OSS 下载后放入即可，
不建议裸传大二进制到 git（用 git-lfs 或 CI download）。

Wintun 驱动 (Windows TUN 模式必需)
================================

wintun.dll 已随此目录分发（BSD 许可，WireGuard 官方发行版 0.14.1 amd64）：

  packages/singbox_flutter/windows/bin/wintun.dll  (~418 KB)

下载源与校验：
  URL   : https://www.wintun.net/builds/wintun-0.14.1.zip
  SHA256: 07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51
  解压路径: wintun/bin/amd64/wintun.dll

mihomo 内核层原生支持 Wintun，只需运行目录下能找到 wintun.dll 即可创建 TUN 网卡。
CMakeLists.txt 会通过 bundled_libraries 把 wintun.dll 也一并 copy 到 Release/。

TUN 模式激活代码路径（尚未实现，见 singbox_flutter_plugin.cpp:188-192）：
方案 C: ShellExecuteEx(runas) 单独提权 mihomo.exe 子进程，velox.exe 保持 asInvoker
不破坏系统代理与开机自启，每 session 仅在用户打开 TUN 时弹一次 UAC。
详细实施 spec 见 memory 条目 [[windows-tun-plan-c]]。
