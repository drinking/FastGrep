# FastGrep 快摘 ⚡️

<p align="center">
  <img src="FastGrep/Assets.xcassets/AppIcon.appiconset/AppIcon-512%402x.png" width="128" height="128" alt="FastGrep Icon" />
</p>

<p align="center">
  <strong>专为 macOS 打造的高效本地文本快摘、代码检索与剪贴板管理器</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-blue?style=flat-square&logo=apple" alt="macOS" />
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-purple?style=flat-square" alt="Architecture" />
</p>

---

## 🌟 核心特性

- ⚡️ **毫秒级模糊搜索与代码快摘**
  - 支持监控本地指定代码库与文档目录（`.swift`, `.py`, `.js`, `.ts`, `.md`, `.json`, `.yaml`, `.txt` 等）。
  - 无论文件路径多深，输入关键词即刻进行毫秒级匹配定位与内容摘取。

- 📋 **增强型剪贴板历史**
  - 自动捕获复制内容并持久化存储，随时通过快捷键回溯、搜索并再次使用。
  - **隐私保护**：智能识别并自动过滤主流密码管理器（1Password、Bitwarden、KeepassXC 等）复制的敏感内容。

- 📂 **深度系统集成与快捷操作**
  - **一键复制**：直接回车（`Return`）复制当前选中的代码或文本段落。
  - **直接打开**：快捷键 `⌥ Return` 或点击按钮，使用系统默认应用程序打开文件。
  - **访达定位**：快捷键 `⌘ Return` 或点击按钮，在 Finder 中高亮显示并定位文件所在目录。

- 🔒 **严格的安全沙盒机制（App Sandbox）**
  - 完全遵循 macOS 原生沙盒规范，采用 Apple 安全范围书签（Security-Scoped Bookmarks）。
  - 电脑重启或应用重开后自动维持监控目录的读写权限，安全无侵入。

- 🚀 **原生现代体验**
  - 状态栏常驻（Menu Bar App），轻量无干扰，内存占用极低。
  - 原生 macOS 14+ 现代设计，完美自适应浅色与深色（Dark Mode）外观。
  - 支持系统原生 **开机自启动**（基于 `SMAppService`，开箱即用）。

---

## ⌨️ 常用快捷键速查

| 操作 | 快捷键 / 触发方式 | 说明 |
| :--- | :--- | :--- |
| **全局呼出 / 隐藏** | `⌃ ⌘ Space` (Control + Command + 空格) | 可在偏好设置中自由更改 |
| **复制所选内容** | `Return` (回车) | 复制内容到系统剪贴板 |
| **打开对应文件** | `⌥ Return` (Option + 回车) | 使用系统默认编辑器打开该文件 |
| **在访达中定位** | `⌘ Return` (Command + 回车) | 在访达 (Finder) 中高亮该文件 |
| **切换剪贴板历史** | 状态栏右键菜单或面板入口 | 查看并搜索近期的剪贴板记录 |
| **AI 提示词模板** | 输入前缀 `/` | 呼出预设的 Prompt 模板 |

---

## 📥 下载与安装

### 方式一：下载预编译版本（推荐）

1. 从 [GitHub Releases](https://github.com/) 下载最新的 `FastGrep-x.x.x.dmg` 安装镜像。
2. 打开 DMG 文件，将 **FastGrep 快摘** 拖入 **Applications**（应用程序）文件夹。
3. 在应用程序中点击打开即可在右上角状态栏看到图标。

> [!TIP]
> **关于 macOS Gatekeeper 提示（“无法打开或已损坏”）**：
> 如果您下载的开源编译版本未经 Apple 付费证书签名公证，macOS 可能会阻止打开。只需打开终端运行以下命令即可正常运行：
> ```bash
> xattr -cr /Applications/FastGrep.app
> ```

### 方式二：从源码编译构建

确保已安装 Xcode 15 或更高版本：

```bash
# 1. 克隆代码仓库
git clone https://github.com/your-username/FastGrep.git
cd FastGrep

# 2. 编译 Release 版本
xcodebuild -project FastGrep.xcodeproj -scheme FastGrep -configuration Release -derivedDataPath ./build build

# 3. 产物生成在 ./build/Build/Products/Release/FastGrep.app
```

---

## 🛠️ 项目架构

```
FastGrep/
├── FastGrep/
│   ├── AppDelegate.swift          # 应用生命周期、状态栏图标与全局快捷键调度
│   ├── ContentView.swift          # 主搜索窗口视图
│   ├── UnifiedListItemView.swift  # 搜索结果项渲染（高亮、标签、快捷键绑定）
│   ├── ClipboardManager.swift     # 剪贴板监听、持久化与密码过滤
│   ├── ClipboardHistoryView.swift # 剪贴板历史查看面板
│   ├── SettingsView.swift         # 偏好设置面板（监控目录、快捷键、开机自启）
│   ├── dbstore.swift              # SQLite 数据库与安全书签持久化
│   ├── request.swift              # 提示词与网络模块
│   ├── FastGrep.entitlements      # App 沙盒权限与安全书签声明
│   └── Assets.xcassets            # 应用与状态栏多分辨率矢量资产
└── FastGrep.xcodeproj             # Xcode 工程文件
```

---

## 🤝 贡献与反馈

欢迎提交 Issue 和 Pull Request！如果你有任何好的建议或功能需求，请随时在 GitHub Discussions 或 Issues 中提出。

## 📄 开源许可证

本项目采用 [MIT License](LICENSE) 开源。