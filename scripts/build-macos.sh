#!/usr/bin/env bash
# 打包 macOS dmg（不签名版，ad-hoc 签名让 Gatekeeper 友好）
#
# 用法: ./scripts/build-macos.sh
# 输出: dist/<AppName>-<Version>-<Arch>.dmg
#
# 依赖: flutter, codesign（macOS 自带）, hdiutil（自带）或 create-dmg（推荐）

set -euo pipefail

# ─── 1. 解析当前 brand 的 PRODUCT_NAME 和 pubspec version ───────
APP_NAME=$(grep '^PRODUCT_NAME' macos/Runner/Configs/AppInfo.xcconfig | sed 's/PRODUCT_NAME = //; s/[[:space:]]*$//')
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+.*//; s/[[:space:]]//g')
ARCH=$(uname -m)
case $ARCH in
  arm64)  ARCH=arm64 ;;
  x86_64) ARCH=x64 ;;
esac

DMG_NAME="${APP_NAME}-${VERSION}-${ARCH}.dmg"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
OUT_DIR="dist"
OUT_DMG="${OUT_DIR}/${DMG_NAME}"

echo "▶ App:     $APP_NAME"
echo "▶ Version: $VERSION"
echo "▶ Arch:    $ARCH"
echo "▶ Output:  $OUT_DMG"
echo ""

# ─── 2. flutter clean + build release ────────────────────────────
echo "▶ flutter clean..."
flutter clean >/dev/null 2>&1
echo "▶ flutter pub get..."
flutter pub get >/dev/null

echo "▶ flutter build macos --release..."
flutter build macos --release

[[ -d "$APP_PATH" ]] || { echo "❌ 未找到 $APP_PATH"; exit 1; }
echo "✅ Built: $APP_PATH"

# ─── 3. ad-hoc 签名（macOS Gatekeeper 友好）──────────────────────
echo "▶ ad-hoc signing..."
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH" && echo "✅ signature valid"

# ─── 4. 打包 dmg ────────────────────────────────────────────────
mkdir -p "$OUT_DIR"
rm -f "$OUT_DMG"

# 4.1 staging 目录: .app + 安装说明.txt + Applications 软链
TMP_DIR=$(mktemp -d)
cp -R "$APP_PATH" "$TMP_DIR/"
ln -s /Applications "$TMP_DIR/Applications"

cat > "$TMP_DIR/安装说明.txt" <<EOF
========================================
  ${APP_NAME} 安装说明
========================================

1. 把 ${APP_NAME}.app 拖到 Applications 文件夹

2. 首次启动遇到「无法打开来自身份不明开发者」？

   方法 A（macOS 14 及之前）:
     右键点击 ${APP_NAME}.app → 选「打开」→ 在弹窗里再点「打开」

   方法 B（macOS 15 Sequoia 及之后 / 推荐）:
     打开「终端」，粘贴并回车执行：

       sudo xattr -cr /Applications/${APP_NAME}.app

     然后双击启动即可。

3. 启动后系统会请求授权（用于设置代理 / TUN 模式），同意即可。

----------------------------------------
版本: ${VERSION}
架构: ${ARCH}
----------------------------------------
EOF

# 4.2 调 create-dmg 或 hdiutil
if command -v create-dmg >/dev/null 2>&1; then
  echo "▶ Using create-dmg..."
  create-dmg \
    --volname "${APP_NAME} ${VERSION}" \
    --window-size 640 420 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 160 200 \
    --app-drop-link 480 200 \
    --add-file "安装说明.txt" "$TMP_DIR/安装说明.txt" 320 360 \
    --no-internet-enable \
    "$OUT_DMG" \
    "$APP_PATH"
else
  echo "▶ Using hdiutil (basic)..."
  hdiutil create \
    -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "$TMP_DIR" \
    -ov -format UDZO \
    "$OUT_DMG"
fi

rm -rf "$TMP_DIR"

# ─── 5. 输出 ─────────────────────────────────────────────────────
SIZE=$(du -h "$OUT_DMG" | awk '{print $1}')
echo ""
echo "🎉 Build complete!"
echo "   $OUT_DMG  ($SIZE)"
echo ""
echo "用户安装步骤:"
echo "   1. 双击 $DMG_NAME 挂载"
echo "   2. 拖 ${APP_NAME}.app 到 Applications"
echo "   3. 首次打开: 右键 ${APP_NAME}.app → 打开 → 确认（绕过 Gatekeeper）"
