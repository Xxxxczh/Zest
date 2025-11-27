#!/bin/bash

# Zest DMG 打包脚本

APP_NAME="Zest"
SOURCE_DIR="./Zest_App"
DMG_NAME="Zest_Installer.dmg"
VOL_NAME="Zest Installer"

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}📦 开始制作 DMG...${NC}"

# 清理旧文件
rm -f "$DMG_NAME"
rm -rf dist

# 准备分发目录
mkdir -p dist
cp -r "$SOURCE_DIR/$APP_NAME.app" dist/
ln -s /Applications dist/Applications

# 创建 DMG
hdiutil create -volname "$VOL_NAME" -srcfolder dist -ov -format UDZO "$DMG_NAME" > /dev/null

# 清理临时目录
rm -rf dist

echo -e "${GREEN}✅ DMG 已生成: $DMG_NAME${NC}"
