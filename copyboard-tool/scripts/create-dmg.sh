#!/bin/bash
# ClipboardHistory DMG 打包脚本
# 使用方法：在项目根目录执行 bash scripts/create-dmg.sh

set -e

APP_NAME="ClipboardHistory"
VERSION="1.1.0"
DMG_NAME="${APP_NAME}_v${VERSION}"

# ---------- 路径配置 ----------
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/ClipboardHistory-dafmubncufuivpaqpxugoncsnavz/Build/Products/Release"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_DIR="$PROJECT_DIR/build"
TMP_DIR="$DMG_DIR/tmp"

echo "📦 开始打包 $APP_NAME v$VERSION"

# ---------- 1. 编译 Release ----------
echo "🔨 编译 Release 版本..."
cd "$PROJECT_DIR"
xcodebuild -project "${APP_NAME}.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    build 2>&1 | grep -E "(error:|BUILD)" || true

if [ ! -d "$APP_PATH" ]; then
    echo "❌ 编译失败：找不到 $APP_PATH"
    exit 1
fi
echo "✅ 编译完成"

# ---------- 2. 准备 DMG 目录 ----------
echo "📁 准备打包目录..."
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# 复制 .app
cp -R "$APP_PATH" "$TMP_DIR/"

# 创建 /Applications 快捷方式
ln -s /Applications "$TMP_DIR/Applications"

echo "✅ 打包目录就绪"

# ---------- 3. 创建 DMG ----------
echo "💿 生成 DMG 文件..."
mkdir -p "$DMG_DIR"
DMG_PATH="$DMG_DIR/$DMG_NAME.dmg"
rm -f "$DMG_PATH"

# 创建临时 DMG（可读写）
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$TMP_DIR" \
    -ov -format UDRW \
    "$DMG_DIR/tmp.dmg" > /dev/null

# 挂载临时 DMG
MOUNT_DIR=$(hdiutil attach "$DMG_DIR/tmp.dmg" -noautoopen -nobrowse | grep "/Volumes/" | awk '{print $3}')
echo "  挂载到 $MOUNT_DIR"

# 设置 DMG 窗口布局
osascript -e "
tell application \"Finder\"
    tell disk \"$APP_NAME\"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 200, 800, 500}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set position of item \"$APP_NAME.app\" of container window to {120, 140}
        set position of item \"Applications\" of container window to {280, 140}
        update without registering applications
        close
    end tell
end tell
" 2>/dev/null

sleep 1

# 卸载并转换为压缩只读 DMG
hdiutil detach "$MOUNT_DIR" -force > /dev/null 2>&1
hdiutil convert "$DMG_DIR/tmp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" > /dev/null 2>&1

# 清理
rm -f "$DMG_DIR/tmp.dmg"
rm -rf "$TMP_DIR"

# ---------- 4. 完成 ----------
FILE_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo ""
echo "============================================"
echo " ✅ DMG 打包完成！"
echo ""
echo " 📦 文件: $DMG_PATH"
echo " 📏 大小: $FILE_SIZE"
echo "============================================"
echo ""
echo "👉 双击 $DMG_NAME.dmg 即可使用"
echo "   将 ClipboardHistory.app 拖到 Applications 文件夹完成安装"
