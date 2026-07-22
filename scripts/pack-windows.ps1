# Windows 打包脚本 — flutter build → 校验产物 → 打 zip → SHA-256
#
# 用法(项目根目录,Windows 上):
#   PowerShell: .\scripts\pack-windows.ps1
#   CMD 双击 : scripts\pack-windows.bat
#   CI 静默 : .\scripts\pack-windows.ps1 -NoPause
#
# 输出:dist\velox-<version>-windows-x64.zip 和 .sha256

param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot  = (Resolve-Path (Join-Path $ScriptDir '..')).Path
Set-Location $RepoRoot

# 解析 pubspec 版本号(取 x.y.z,丢掉 +build)
$verLine = Get-Content pubspec.yaml | Where-Object { $_ -match '^version:\s*(\S+)' } | Select-Object -First 1
if (-not $verLine) { throw 'pubspec.yaml 里没找到 version:' }
$null = $verLine -match '^version:\s*(\S+)'
$Version = $Matches[1] -replace '\+.*',''

$AppName  = 'velox'
$OutDir   = Join-Path $RepoRoot 'dist'

Write-Host "[i] App     : $AppName"
Write-Host "[i] Version : $Version"
Write-Host ''

Write-Host '[*] flutter pub get ...'
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed ($LASTEXITCODE)" }

Write-Host '[*] flutter build windows --release ...'
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed ($LASTEXITCODE)" }

# 自动识别 build 产物架构 (x64 / arm64)
$X64Dir   = Join-Path $RepoRoot 'build\windows\x64\runner\Release'
$Arm64Dir = Join-Path $RepoRoot 'build\windows\arm64\runner\Release'
if (Test-Path (Join-Path $X64Dir 'velox.exe')) {
    $BuildDir = $X64Dir; $Arch = 'x64'
} elseif (Test-Path (Join-Path $Arm64Dir 'velox.exe')) {
    $BuildDir = $Arm64Dir; $Arch = 'arm64'
} else {
    throw "[X] 找不到 velox.exe (x64 或 arm64 目录都没有)"
}
Write-Host "[i] Arch    : $Arch"
Write-Host "[i] BuildDir: $BuildDir"

$ZipName = "$AppName-$Version-windows-$Arch.zip"
$ZipPath = Join-Path $OutDir $ZipName
Write-Host "[i] Output  : $ZipPath"

# 关键产物校验清单 — 缺任何一个立即报错
$Required = @(
    "$BuildDir\velox.exe",
    "$BuildDir\flutter_windows.dll",
    "$BuildDir\mihomo.exe",
    "$BuildDir\data\icudtl.dat",
    "$BuildDir\data\flutter_assets"
)
foreach ($f in $Required) {
    if (-not (Test-Path $f)) { throw "[X] 缺少产物: $f" }
}
# Wintun DLL 可选(方案 C 落地后才有)—— 存在就一起打
if (Test-Path "$BuildDir\wintun.dll") {
    Write-Host '[i] wintun.dll 存在,一起打入'
}
Write-Host '[ok] 产物完整'

# 打包(顶层带 velox-<ver>/ 目录,解压不污染桌面)
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

$Staging = Join-Path $env:TEMP "velox-pack-$Version-$([Guid]::NewGuid().ToString('N'))"
$AppRoot = Join-Path $Staging "$AppName-$Version"
New-Item -ItemType Directory -Path $AppRoot -Force | Out-Null
Copy-Item -Path "$BuildDir\*" -Destination $AppRoot -Recurse -Force

$readme = @"
$AppName $Version - Windows $Arch (portable)

首次启动:
  1. 解压整个文件夹到任意目录(推荐 D:\Apps\$AppName)
  2. 双击 $AppName.exe
  3. Windows Defender / SmartScreen 拦截 => 更多信息 => 仍要运行
  4. 首次启用 TUN 模式会弹 UAC 请求管理员权限

组件:
  $AppName.exe                主程序(Flutter)
  mihomo.exe                  VPN 核心(MetaCubeX/mihomo)
  wintun.dll                  TUN 模式驱动(BSD,WireGuard 官方发行)
  flutter_windows.dll         Flutter runtime
  singbox_flutter_plugin.dll  桥接插件
  data\flutter_assets\        资源(图标/geo/翻译)

卸载: 直接删除整个文件夹(配置写在 %APPDATA%\$AppName,如需清理一并删除)
"@
$readme | Set-Content -Path (Join-Path $AppRoot 'README.txt') -Encoding UTF8

Write-Host '[*] 压缩中 ...'
Compress-Archive -Path (Join-Path $Staging '*') -DestinationPath $ZipPath -CompressionLevel Optimal
Remove-Item $Staging -Recurse -Force

# SHA-256
$Hash = (Get-FileHash -Algorithm SHA256 $ZipPath).Hash.ToLower()
"$Hash  $ZipName" | Set-Content -Path "$ZipPath.sha256" -Encoding ASCII

$Size = '{0:N2} MB' -f ((Get-Item $ZipPath).Length / 1MB)
Write-Host ''
Write-Host '=========================================='
Write-Host '[OK] 打包完成'
Write-Host "     File   : $ZipPath  ($Size)"
Write-Host "     SHA256 : $Hash"
Write-Host '=========================================='

if (-not $NoPause -and $env:CI -ne 'true') {
    Write-Host ''
    Read-Host '按 Enter 退出'
}
