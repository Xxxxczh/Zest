#!/bin/bash

# Zest 构建脚本
# 功能：编译 Universal Binary，生成 App Bundle，自制图标，签名

APP_NAME="Zest"
BUNDLE_ID="com.orange.zest"
OUTPUT_DIR="./Zest_App"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
BINARY_NAME="Zest"
MODULE_CACHE_DIR="$PWD/.build/modulecache"
CLANG_CACHE_DIR="$PWD/.build/clangmodulecache"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🍊 开始构建 Zest (Release)...${NC}"

# 1. 准备环境
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$MODULE_CACHE_DIR" "$CLANG_CACHE_DIR"
export SWIFTPM_MODULECACHE_PATH="$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR"

# 2. 编译 ARM64 (Apple Silicon)
echo -e "${BLUE}🔨 编译 ARM64...${NC}"
swift build -c release --arch arm64
if [ $? -ne 0 ]; then echo "❌ ARM64 编译失败"; exit 1; fi

# 3. 编译 x86_64 (Intel)
echo -e "${BLUE}🔨 编译 x86_64...${NC}"
swift build -c release --arch x86_64
if [ $? -ne 0 ]; then echo "❌ x86_64 编译失败"; exit 1; fi

# 4. 创建 App 结构
echo -e "${BLUE}📂 组装 App Bundle...${NC}"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 5. 合并二进制 (Lipo)
echo -e "${BLUE}🔗 合并通用二进制...${NC}"
lipo -create \
    .build/arm64-apple-macosx/release/$BINARY_NAME \
    .build/x86_64-apple-macosx/release/$BINARY_NAME \
    -output "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"

# 6. 生成应用图标 (代码绘制)
echo -e "${BLUE}🎨 绘制 Zest 图标...${NC}"
cat > IconGen.swift <<EOF
import Cocoa

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

// 1. 背景 (橙色圆角矩形)
let rect = NSRect(origin: .zero, size: size)
let path = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
let gradient = NSGradient(starting: NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0), ending: NSColor(red: 1.0, green: 0.3, blue: 0.0, alpha: 1.0))!
gradient.draw(in: path, angle: -45)

// 2. 文字 (Z)
let text = "Z" as NSString
let font = NSFont.systemFont(ofSize: 600, weight: .heavy)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
    .shadow: {
        let s = NSShadow()
        s.shadowOffset = NSSize(width: 0, height: -10)
        s.shadowBlurRadius = 20
        s.shadowColor = NSColor.black.withAlphaComponent(0.2)
        return s
    }()
]
let textSize = text.size(withAttributes: attrs)
let textRect = NSRect(
    x: (size.width - textSize.width) / 2,
    y: (size.height - textSize.height) / 2,
    width: textSize.width,
    height: textSize.height
)
text.draw(in: textRect, withAttributes: attrs)

image.unlockFocus()

if let tiff = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiff),
   let png = bitmap.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: "icon_1024.png"))
}
EOF

swift IconGen.swift

# 生成 iconset
mkdir -p AppIcon.iconset
sips -z 16 16     icon_1024.png --out AppIcon.iconset/icon_16x16.png > /dev/null
sips -z 32 32     icon_1024.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null
sips -z 32 32     icon_1024.png --out AppIcon.iconset/icon_32x32.png > /dev/null
sips -z 64 64     icon_1024.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null
sips -z 128 128   icon_1024.png --out AppIcon.iconset/icon_128x128.png > /dev/null
sips -z 256 256   icon_1024.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null
sips -z 256 256   icon_1024.png --out AppIcon.iconset/icon_256x256.png > /dev/null
sips -z 512 512   icon_1024.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null
sips -z 512 512   icon_1024.png --out AppIcon.iconset/icon_512x512.png > /dev/null
sips -z 1024 1024 icon_1024.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null

iconutil -c icns AppIcon.iconset
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# 清理图标临时文件
rm IconGen.swift icon_1024.png
rm -rf AppIcon.iconset

# 7. 写入 Info.plist
echo -e "${BLUE}📝 配置 Info.plist...${NC}"
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$BINARY_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# 8. 签名
echo -e "${BLUE}🔏 应用签名...${NC}"
codesign --force --deep --sign - "$APP_BUNDLE"

echo -e "${GREEN}✅ 构建完成！${NC}"
