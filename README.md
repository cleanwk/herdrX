# HerdrX

原生 macOS Herdr 工作台：在一个窗口里管理本机和 SSH 设备上的 Space、标签、分屏终端与编码 Agent。SwiftUI / AppKit 界面，Ghostty 渲染原始终端字节，Herdr 管理服务端会话与扩展。

![HerdrX icon](Resources/Icon/Preview.png)

支持 macOS 14+，发布包同时包含 Apple Silicon 和 Intel。

## 安装与升级

主要分发渠道是现有的 [cleanwk/homebrew-tap](https://github.com/cleanwk/homebrew-tap)。每次稳定版本发布后，GitHub Actions 自动打包并更新 `herdrx` cask：

```sh
brew install --cask cleanwk/tap/herdrx
brew update && brew upgrade --cask herdrx
```

默认版本采用 ad-hoc 签名，不需要 Apple Developer ID 或公证凭据。首次打开若被 macOS 拦截，先尝试启动，再到系统设置 → 隐私与安全 → 仍要打开。Brew 保留正常 quarantine 检查，应用更新后可能需要再次确认。若明确接受当前未公证版本，安装后只对本 App 执行 `xattr -dr com.apple.quarantine /Applications/HerdrX.app`，无需关闭全局 Gatekeeper。CI 的预览包不作为正式版本同步；版本 tag 发布的稳定包才同步到 cask。见 [Release](docs/Release.md)。

## 使用

启动后立即得到一个本地 Shell，无需先配置服务器。Settings → Devices 可添加本机命名会话或 SSH 连接。每个连接填写对应 Herdr 实例的**绝对 socket 路径**；SSH 使用系统 `ssh`、现有密钥和 SSH config。请先在 Terminal 中完成该主机的首次信任与登录。

本机默认读取 `~/.config/herdr/herdr.sock`。需要在对应设备安装并运行 Herdr；已核对的契约版本是 **Herdr 0.9.3 / protocol 22**。普通 Shell 的运行不依赖 Herdr。

选择服务器 Space 会附着该标签的终端，并使用 Herdr 的 `--takeover` 语义。后续切换标签复用同一 attach。其他客户端接管后，点击 Reconnect 手动恢复。退出 HerdrX 或删除设备连接只会断开客户端；关闭服务器 Pane 会另行确认，因为它会终止服务端进程。

| 快捷键 | 操作 |
| --- | --- |
| ⌘N / ⌘T | 新建 Agent / Shell |
| ⌘⇧N / ⌘⌥T | 新建 Space / Tab |
| ⌘D / ⌘⇧D | 向右 / 向下分屏，继承当前目录 |
| ⌘⌥方向键 / ⌘⌃方向键 | 移动焦点 / 调整分屏比例 |
| ⌘⇧Return | 放大或还原当前 Pane |
| ⌘1…9 / ⌘⇧[ / ⌘⇧] | 选择或轮换标签 |
| ⌘W | 关闭当前 Pane；最后一个本地 Shell 关闭窗口 |
| ⌘B | 隐藏或显示侧栏 |
| ⌘K | 搜索 Space、Shell 与 Agent，支持拼音和首字母 |
| ⌘⇧J | 跳至其他等待输入或已完成的 Agent |
| ⌘⇧R | 恢复终端输入模式 |

侧栏分隔线可拖动，双击恢复默认宽度。分屏分隔线支持拖动；服务端比例在放开鼠标时提交。New Agent 从 Herdr 获取可用工具，选择设备、空间与可选参数后启动；New Space 显式输入名称和目录。侧栏按设备筛选，Space 右键重命名。Settings → Appearance 选择系统、浅色或深色；Terminal 调整字体和行距并预览，Notifications 主动开启通知及声音，点击提醒返回对应 Pane。HerdrX 不内置文件目录、文件预览或文件传输。

## Herdr 扩展

沿用 Herdr 原有的 TOML manifest 与 `plugin.*` API。通过 `herdr plugin install` 在目标设备安装扩展，在 Settings → Plugins 查看、启停、运行动作、阅读日志或以 Tab 打开终端面板。执行上下文由 GUI 传给 Herdr，扩展进程由 Herdr 托管。

Herdr v1 的扩展面板是终端面板；HerdrX 不另建 manifest、插件进程管理器、权限协议或 Schema UI。ACC 业务不在本项目范围内。元数据标题、状态标签及 workspace token 直接来自 Herdr。[上游插件契约](https://github.com/herdrdev/herdr/blob/v0.9.3/docs/next/website/src/content/docs/plugins.mdx)。

## 构建

安装 Xcode 27、完成首次启动，并安装 XcodeGen：

```sh
brew install xcodegen
scripts/build.sh
scripts/package.sh
```

产物在 `build/release/Build/Products/Release/HerdrX.app`，ZIP 和校验信息在 `build/dist/`。默认采用本地 ad-hoc 签名。`SIGN_IDENTITY`、`NOTARIZE=1` 和 Apple 凭据用于正式包，见发布文档。

日常开发：`xcodegen generate` 后打开生成的 `HerdrX.xcodeproj`。Debug 使用独立 bundle ID，避免与已安装的发布版混淆。纯通信核心可单独验证：

```sh
swift test --package-path Core -c release
python3 -m unittest discover -s scripts -p 'test_*.py'
```

代码分为 `App`、`Core`、`scripts` 和 `distribution` 四块；见 [Architecture](docs/Architecture.md)、[Validation](docs/Validation.md) 和 [第三方许可](Resources/Notices.txt)。
