# Zest

macOS 上的快捷剪贴板工具，支持历史记录、图片/文件粘贴、全键盘操作与搜索。

## 功能特性
- 剪贴板历史：文本、图片、文件自动收集，支持固定/删除。
- 搜索与过滤：快捷搜索，按类型过滤（文本/图片/文件）。
- 快捷键导航：↑↓ 浏览，←→ 切换类型，Enter 粘贴，⌘1-9 快速选择。
- 菜单栏常驻：随时呼出历史面板。
- 自动打包：`package.sh` 生成通用二进制与 `.app`，`create_dmg.sh` 生成 DMG。

## 安装
- 从 Release 下载最新 DMG：<https://github.com/Xxxxczh/Zest/releases>
- 双击挂载后，将 `Zest.app` 拖入应用程序。

## 开发
```bash
swift build -c debug      # 开发构建
swift test                 # 运行单元测试
package.sh                 # 生成 Zest_App/Zest.app（通用架构）
create_dmg.sh              # 从 Zest_App 生成 Zest_Installer.dmg
```

## 权限
- 辅助功能：用于模拟粘贴快捷键。
- 剪贴板访问：读取粘贴板内容。
