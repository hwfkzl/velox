#!/usr/bin/env bash
# 切换客户端品牌（一次性写入：图标、显示名、原生工程标识）
#
# 用法: ./scripts/set-brand.sh <brand>
# 例:   ./scripts/set-brand.sh globalfast
#
# 资源约定: brands/<brand>/{brand.yaml, icon.png}
#   brand.yaml 字段: display_name / splash_text / description
#
# 不会改动:
#   - UA 协议层 (lib/core/services/user_agent_service.dart)
#   - bundle id (com.example.velox 或类似)
#   - Dart package name (pubspec.yaml: name:)

set -euo pipefail

BRAND="${1:-}"
if [[ -z "$BRAND" ]]; then
  echo "Usage: $0 <brand>"
  echo "Available brands:"
  ls -1 brands 2>/dev/null | sed 's/^/  /'
  exit 1
fi

DIR="brands/$BRAND"
[[ -d $DIR ]] || { echo "❌ brand not found: $DIR"; exit 1; }
[[ -f $DIR/icon.png ]] || { echo "❌ missing $DIR/icon.png"; exit 1; }
[[ -f $DIR/brand.yaml ]] || { echo "❌ missing $DIR/brand.yaml"; exit 1; }

# ─── 解析 brand.yaml ────────────────────────────────────────────
read_yaml() {
  grep "^$1:" "$DIR/brand.yaml" | sed -E "s/^$1: *//; s/^[\"']//; s/[\"']$//"
}
NAME=$(read_yaml display_name)
SPLASH=$(read_yaml splash_text)
DESC=$(read_yaml description)

[[ -n "$NAME" ]] || { echo "❌ display_name missing in $DIR/brand.yaml"; exit 1; }
SPLASH="${SPLASH:-$NAME}"

echo "▶ Brand:        $BRAND"
echo "▶ Display Name: $NAME"
echo "▶ Splash Text:  $SPLASH"

# ─── 1. 图标资源 ─────────────────────────────────────────────────
mkdir -p assets/icons
cp -f "$DIR/icon.png" assets/icons/app_icon.png
echo "✅ icon → assets/icons/app_icon.png"

# ─── 2. flutter_launcher_icons (切多平台多尺寸) ──────────────────
echo "▶ Running flutter_launcher_icons..."
flutter pub get >/dev/null
flutter pub run flutter_launcher_icons >/dev/null
echo "✅ launcher icons regenerated"

# ─── 3. iOS Info.plist ──────────────────────────────────────────
plutil -replace CFBundleDisplayName -string "$NAME" ios/Runner/Info.plist
plutil -replace CFBundleName        -string "$NAME" ios/Runner/Info.plist
echo "✅ iOS Info.plist"

# ─── 4. Android AndroidManifest.xml ─────────────────────────────
sed -i '' -E "s|android:label=\"[^\"]*\"|android:label=\"$NAME\"|" \
  android/app/src/main/AndroidManifest.xml
echo "✅ Android AndroidManifest.xml"

# ─── 5. macOS xcconfig ──────────────────────────────────────────
sed -i '' -E "s/^PRODUCT_NAME = .*/PRODUCT_NAME = $NAME/" \
  macos/Runner/Configs/AppInfo.xcconfig
echo "✅ macOS PRODUCT_NAME"

# ─── 6. Windows Runner.rc + main.cpp ────────────────────────────
sed -i '' -E "s/(VALUE \"CompanyName\", )\"[^\"]*\"/\1\"$NAME\"/" windows/runner/Runner.rc
sed -i '' -E "s/(VALUE \"FileDescription\", )\"[^\"]*\"/\1\"$NAME\"/" windows/runner/Runner.rc
sed -i '' -E "s/(VALUE \"InternalName\", )\"[^\"]*\"/\1\"$NAME\"/" windows/runner/Runner.rc
sed -i '' -E "s/(VALUE \"OriginalFilename\", )\"[^\"]*\"/\1\"$NAME.exe\"/" windows/runner/Runner.rc
sed -i '' -E "s/(VALUE \"ProductName\", )\"[^\"]*\"/\1\"$NAME\"/" windows/runner/Runner.rc
sed -i '' -E "s/(VALUE \"LegalCopyright\", )\"[^\"]*\"/\1\"Copyright (C) 2026 $NAME. All rights reserved.\"/" windows/runner/Runner.rc
sed -i '' -E "s/window\.Create\(L\"[^\"]*\"/window.Create(L\"$NAME\"/" windows/runner/main.cpp
echo "✅ Windows Runner.rc + main.cpp"

# ─── 7. lib/app/brand.dart 默认值 ───────────────────────────────
sed -i '' -E "s/(defaultValue: ')[^']*(',  *\/\/ BRAND_NAME)/\1$NAME\2/" lib/app/brand.dart 2>/dev/null || true
# 容错: 没有锚点注释时用通用替换
python3 - "$NAME" "$SPLASH" <<'PYEOF'
import re, sys
name, splash = sys.argv[1], sys.argv[2]
p = 'lib/app/brand.dart'
s = open(p).read()
s = re.sub(
  r"(static const String name = String\.fromEnvironment\(\s*'BRAND_NAME',\s*defaultValue: ')[^']*(',\s*\);)",
  rf"\g<1>{name}\g<2>", s, flags=re.S)
s = re.sub(
  r"(static const String splashText = String\.fromEnvironment\(\s*'BRAND_SPLASH',\s*defaultValue: ')[^']*(',\s*\);)",
  rf"\g<1>{splash}\g<2>", s, flags=re.S)
open(p, 'w').write(s)
PYEOF
echo "✅ lib/app/brand.dart defaults"

# ─── 8. pubspec.yaml description (可选) ─────────────────────────
if [[ -n "$DESC" ]]; then
  sed -i '' -E "s/^description: .*/description: \"$DESC\"/" pubspec.yaml
  echo "✅ pubspec.yaml description"
fi

# ─── 9. .env (brand 专属后端 URL) ───────────────────────────────
# brands/<brand>/.env 优先；不存在就保留当前 .env 不动
if [[ -f "$DIR/.env" ]]; then
  cp -f "$DIR/.env" .env
  echo "✅ .env (from $DIR/.env)"
else
  echo "ℹ  no $DIR/.env, keeping existing .env"
fi

echo ""
echo "🎉 Brand switched to: $NAME"
echo ""
echo "Next steps:"
echo "  flutter clean"
echo "  flutter build macos     # → build/macos/Build/Products/Release/$NAME.app"
echo "  flutter build apk       # → build/app/outputs/flutter-apk/app-release.apk"
echo "  flutter build windows   # → build/windows/x64/runner/Release/$NAME.exe"
