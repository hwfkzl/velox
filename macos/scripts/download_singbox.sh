#!/bin/bash
# 下载 sing-box Universal Binary (arm64 + x86_64) 并放入 macos/Resources/
# 用法: bash macos/scripts/download_singbox.sh [版本号]
# 示例: bash macos/scripts/download_singbox.sh 1.11.5

set -e

VERSION="${1:-1.11.5}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCES_DIR="$SCRIPT_DIR/../Resources"
DEST="$RESOURCES_DIR/sing-box"

echo "==> 目标版本: sing-box v${VERSION}"
echo "==> 输出目录: $RESOURCES_DIR"

mkdir -p "$RESOURCES_DIR"

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

ARM64_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-darwin-arm64.tar.gz"
X86_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-darwin-amd64.tar.gz"

echo "==> 下载 arm64..."
curl -L "$ARM64_URL" -o "$TMP_DIR/arm64.tar.gz"
tar -xf "$TMP_DIR/arm64.tar.gz" -C "$TMP_DIR"
ARM64_BIN=$(find "$TMP_DIR" -name "sing-box" -type f | head -1)

echo "==> 下载 x86_64..."
curl -L "$X86_URL" -o "$TMP_DIR/amd64.tar.gz"
tar -xf "$TMP_DIR/amd64.tar.gz" -C "$TMP_DIR"
X86_BIN=$(find "$TMP_DIR" -name "sing-box" -not -samefile "$ARM64_BIN" -type f | head -1)

echo "==> 合并为 Universal Binary..."
lipo -create "$ARM64_BIN" "$X86_BIN" -output "$DEST"
chmod +x "$DEST"

echo "==> 验证..."
file "$DEST"
"$DEST" version

echo ""
echo "✅ 成功: $DEST"
echo "   现在可以运行 flutter build macos 打包含 sing-box 的 App"
