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
| ⌘N / ⌘T | 新建 Agent / 当前设备终端（也可从新建菜单打开独立 Shell） |
| ⌘⇧N / ⌘⌥T | 继承当前目录快速新建 Space / Tab |
| ⌘D / ⌘⇧D | 向右 / 向下分屏，继承当前目录 |
| ⌘⌥方向键 / ⌘⌃方向键 | 移动焦点 / 调整分屏比例 |
| ⌘⇧Return | 放大或还原当前 Pane |
| ⌘1…9 / ⌘⇧[ / ⌘⇧] | 选择或轮换标签 |
| ⌘W | 优先关闭 Sheet，然后当前 Pane，无目标时关闭窗口 |
| ⌘⇧W / ⌘⌥W | 关闭 Pane / Tab |
| ⌘B | 隐藏或显示侧栏 |
| ⌘K | 搜索 Space、Shell 与 Agent，支持拼音和首字母 |
| ⌘⇧J | 跳至等待输入或未读完成的 Agent |
| ⌘⇧R | 恢复终端输入模式（不发送 Ctrl-C） |
| ⌘⇧E / ⌘⇧F | 文件辅助区 / 双端文件管理 |

侧栏宽度200–480pt并持久保存，双击恢复260pt；分组可折叠。分屏比例在放开鼠标时提交。New Agent从目标Herdr获取工具与目录上下文；快速New Space继承当前目录，高级表单保留明确名称和目录。Space、Tab、Pane均有对象菜单；Agent未读与系统通知分别管理。

Settings提供外观/配色/强调色/语言、终端字体/字重/行距/鼠标/复制，以及本机Agent命令覆盖。文件辅助区默认隐藏，可只读预览最多2MiB的文本或图片；文件管理支持本机/SSH单文件传输、冲突处理和取消。SSH文件操作要求目标设备有Python3。

Tailcat设置与传输helper已实现，凭据保存在独立Keychain命名空间；尚未在真实Tailcat host验收，且不支持文件操作。本轮完整实现状态、截图及未验证边界见[复刻验收记录](docs/parity/STATUS.md)，不是全功能通过声明。

## Herdr 扩展

沿用 Herdr 原有的 TOML manifest 与 `plugin.*` API。通过 `herdr plugin install` 在目标设备安装扩展，在 Settings → Plugins 查看、启停、运行动作、阅读日志或以 Tab 打开终端面板。执行上下文由 GUI 传给 Herdr，扩展进程由 Herdr 托管。

Herdr v1 的扩展面板是终端面板；HerdrX 不另建 manifest、插件进程管理器、权限协议或 Schema UI。ACC 业务不在本项目范围内。元数据标题、状态标签及 workspace token 直接来自 Herdr。[上游插件契约](https://github.com/herdrdev/herdr/blob/v0.9.3/docs/next/website/src/content/docs/plugins.mdx)。

## 构建

安装 Xcode 27、完成首次启动，并安装 XcodeGen 和 Go（Tailcat helper 使用 `Tools/Tailcat/go.mod` 指定的工具链）：

```sh
brew install xcodegen go
scripts/build.sh
scripts/package.sh
```

产物在 `build/release/Build/Products/Release/HerdrX.app`，ZIP 和校验信息在 `build/dist/`。默认采用本地 ad-hoc 签名。`SIGN_IDENTITY`、`NOTARIZE=1` 和 Apple 凭据用于正式包，见发布文档。

日常开发：`xcodegen generate` 后打开生成的 `HerdrX.xcodeproj`。Debug 使用独立 bundle ID，避免与已安装的发布版混淆。纯通信核心可单独验证：

```sh
swift test --package-path Core -c release
python3 -m unittest discover -s scripts -p 'test_*.py'
scripts/test-pty.sh
scripts/test-ssh.sh
```

代码分为 `App`、`Core`、`scripts` 和 `distribution` 四块；见 [Architecture](docs/Architecture.md)、[Validation](docs/Validation.md) 和 [第三方许可](Resources/Notices.txt)。
