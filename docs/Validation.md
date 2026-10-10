> 历史记录：本文件描述此前版本。当前功能减法、删除范围和逐项结果以 [本轮验收](ux-audit/RESULTS.md) 为准；不得按旧清单恢复 Agent 启动器、文件预览、传输或附件投递。

# Validation

验证日期：2026-10-10。本机 Xcode 27 / Apple Silicon。实际运行的 Herdr 为 0.9.3，protocol 22。

## 自动验证

- 纯核心 release 测试 10 项通过：NDJSON 分片/限幅、设备隔离、Herdr 插件记录、400 条搜索及拼音、拒绝不完整快照、真实 Unix socket 大响应重组、响应身份拒绝、快照错误直接报告及 argv 参数边界、events_lost 报错。
- 发布契约 Python 测试 4 项通过：有效 cask、接受明确标记的 ad-hoc 包，拒绝错误架构/错误版本/错误摘要、拒绝预览与注入 tag。
- SwiftPM、Xcode 原生 Debug 和 universal Release 构建通过；真实二进制包含 arm64 与 x86_64，codesign --verify --deep --strict 通过。开发预览 ZIP 已生成，公证标记为 false；最终 universal 应用已实际启动，标签、分屏和终端输出正常，文件浏览入口已移除。
- 原始插画、1024 图标输入及 native preview 都保留生成来源，Icon Composer 编译通过，legacy ICNS 含完整 16–1024 尺寸。

## 实际界面

实际原生窗口已验证本地终端输入、命令输出、创建分屏。侧栏从正在运行的本机 Herdr 读取工作区与 Agent，未为测试修改用户的服务端会话。

开发版与发布版使用不同 bundle ID。最新构建验证：分屏实时继承 /tmp；拖动比例有效；切换标签后隐藏终端的 stty size 前后均为 35 × 67；⌘K 搜索本地 Shell 并回车选择；Devices、Plugins 空态及 Terminal 设置页面。官方本机事件订阅响应 subscription_started。使用独立 XDG config/state 目录启动临时 Herdr，真实验证了插件 list、action.invoke、执行日志成功及 stdout、pane.open 返回可 attach 的 Pane、terminal attach 收到面板内容、enable/disable。临时测试插件不随应用分发，也没有注册到用户现有的 Herdr 配置。截图只保存在忽略的本地 review 目录，不将用户工作区名称发布到仓库。

## 尚无证据的范围

未进行真实远端 SSH、第三方插件动作及面板执行、Intel 机器运行、macOS 14/15 运行、第三方语音输入法或全部 Agent TUI 的验收。Universal 架构验证不等同于 Intel 实机验证。400 条搜索测试不代表 400 个活跃终端的内存或吞吐指标。

Developer ID 与公证凭据为可选；默认采用 ad-hoc 签名。正式 Release 与安装后 Brew 升级的端到端验证在首次版本发布后完成。发布同步脚本和门槛已通过本地契约测试。

## Herdrm 对比后的验证

实际 Brew 安装 v0.1.2，核对下载包与安装后的二进制一致；本 App 放行后冷启动、本地命令输出、分屏通过。没有关闭全局 Gatekeeper或使用管理员密码。新增功能与验收限制见 [Comparison](Comparison.md)。临时 Herdr 实例验证创建/重命名 Space、创建 Tab及工具目录，完成后已停止。真实 SSH 重连和通知点击仍需实际环境验收。
