# NotchDrop

**利用 MacBook 刘海区域的临时文件存放工具。**

NotchDrop 是一个 macOS 菜单栏应用，利用 MacBook 屏幕顶部刘海区域作为触发区，提供一个临时存放文件的浮动面板。

## 功能

- **拖入即存** — 从 Finder 拖拽文件到面板，文件自动移入内部存储，源文件删除（剪切）
- **刘海触发** — 鼠标悬停或拖拽文件到屏幕顶部中央，面板自动弹出
- **多选操作** — ⌘+单击、⇧+单击、框选（rubber-band selection），批量移回原位置
- **面板框选** — 在文件列表空白处拖拽进行框选
- **移回原位置** — 点击「移回」文件自动恢复到原始路径
- **自动隐藏** — 可设置延迟（1-10s），操作面板时计时器自动重置
- **中英双语** — 设置中切换 English / 简体中文
- **开机启动** — 可选登录时自动启动
- **记忆文件** — 可选退出后保留文件，下次启动恢复

## 使用方式

| 操作 | 行为 |
|------|------|
| 左键点击状态栏图标 | 展开/收起面板 |
| 右键点击状态栏图标 | 弹出菜单 |
| `⌃⌘N` | 展开/收起面板 |
| 鼠标悬停屏幕顶部中央 | 展开面板 |
| 拖拽文件到屏幕顶部 | 展开面板并接收文件 |
| 点击面板内文件 | 打开文件 |
| 拖拽面板内文件到 Finder | 文件移出面板（剪切） |
| 右键 → 移回原位置 | 文件恢复至原始路径 |
| 选中多个文件 → 移回 | 批量恢复 |

## 截图

截屏待添加

## 系统要求

- macOS 14.0+
- Apple Silicon 或 Intel
- 带有刘海的 MacBook（非必须，但体验最佳）

## 安装

1. 从 [Releases](https://github.com/kail896/NotchDrop/releases) 下载最新 `NotchDrop.dmg`
2. 打开 DMG，将 `NotchDrop.app` 拖入 `Applications` 文件夹
3. 首次运行可能需要右键 → 打开（绕过 Gatekeeper）

## 构建

```bash
git clone https://github.com/kail896/NotchDrop.git
cd NotchDrop
swift build -c release
cp -r .build/release/NotchDrop NotchDrop.app/Contents/MacOS/
cp Info.plist NotchDrop.app/Contents/
cp AppIcon.icns NotchDrop.app/Contents/Resources/
```

或使用构建脚本：

```bash
./build.sh
```

## 技术栈

- SwiftUI + AppKit 混合架构
- Swift Package Manager
- 原生 macOS API（NSPanel、NSDraggingSource、NSTrackingArea）

## 许可证

MIT License
