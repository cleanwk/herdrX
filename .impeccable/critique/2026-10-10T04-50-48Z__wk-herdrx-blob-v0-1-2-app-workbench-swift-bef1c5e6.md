---
target: HerdrX v0.1.2 versus Herdrm v0.6.14
total_score: 21
max_score: 36
na_heuristics: 9
p0_count: 0
p1_count: 2
target_identity: "url:https://github.com/cleanwk/herdrX/blob/v0.1.2/App/Workbench.swift"
timestamp: 2026-10-10T04-50-48Z
slug: wk-herdrx-blob-v0-1-2-app-workbench-swift-bef1c5e6
---
# Herdrm 对比与改进

日期：2026-10-10。基线：HerdrX v0.1.2；参考：[官方 Herdrm v0.6.14](https://github.com/missuo/herdrm/releases/tag/v0.6.14)。

Method: dual-agent (A: herdrm_visual_review · B: herdrm_function_review)

实际下载并运行官方应用，截图检查主界面、搜索、Agent/Space 创建、Appearance、Terminal、Agent、Notifications、Tailcat、About 设置；同时检查 HerdrX 全部应用与核心源码。参考项目仅使用发布二进制、界面和公开 README，没有下载或复制参考源码。实现依照本机 Herdr 0.9.3 / protocol 22 官方 schema 和实际 RPC 响应独立编写。

## 判断

Herdrm 更成熟的地方是操作上下文：创建前明确工具、目的空间和参数，搜索提供识别线索，通知和连接恢复形成完整操作链。HerdrX 的终端主导布局更安静，Ghostty 原生表面复用、设备隔离、官方插件接口和关闭确认已有良好基础。渲染性能没有进行两应用基准测试，不能据此宣称 Ghostty 更快。

基线界面启发式评分如下；这是截图与源码审查判断，不是可用性实验，也不是改进后评分。

| 维度 | 分数 / 4 |
| --- | --- |
| 状态可见性 | 3 |
| 贴近实际任务 | 2 |
| 用户控制 | 2 |
| 平台一致性 | 3 |
| 错误预防 | 2 |
| 识别优于记忆 | 2 |
| 操作效率 | 2 |
| 视觉简洁 | 3 |
| 错误恢复 | 未运行验证 |
| 帮助 | 2 |

合计 21/36。首轮评估，没有历史趋势。首次使用者最容易在创建目的地和相似 shell 名称上迷失；熟练使用者会受缺少工具目录、连接恢复及通知跳转影响。

两项优先问题：P1 创建 Agent 固定四个工具且不提供空间/参数；P1 SSH 退出后重复连接失效 socket，不会重建隧道。其余导航、搜索、设置及通知改进随同完成。

## 本轮实现

| 功能 | 基线差距 | 独立实现 |
| --- | --- | --- |
| Agent 创建 | 四个固定按钮，立即执行 | 读取 `integration.list` 的 available 工具，选择设备/Space/参数，确认 Launch；参数转 argv，无 shell 展开 |
| Space 创建 | 本地默认选择下会误开 shell | 设备、名称、绝对目录表单，调用 `workspace.create`，无文件浏览器 |
| 导航 | 普通服务器终端没有直接列表 | 加入终端分组、设备过滤、Agent 空间/工具/状态，编号本地 shell、⌘B 隐藏侧栏 |
| Space 重命名 | 缺失 | 原生上下文菜单，调用 `workspace.rename` |
| 搜索 | 缺少图标与键盘提示 | 类型图标、键盘提示、选中结果居中可见；保持拼音/首字母相关度，同层按状态优先 |
| SSH 恢复 | 隧道只建立一次 | 1–30 秒退避、连接超时、keepalive、每次重建失败隧道；保留快照且不自动争抢 attach |
| 通知 | 无点击路由，观看中仍提示 | Agent 状态转换携带设备/Pane 路由、点击跳转、当前 Pane 静音、声音与系统权限说明 |
| 设置 | 终端设置混入通知，缺少预览 | Appearance、Notifications 独立设置；终端字体样本与恢复默认值 |
| 插件上下文 | 没有 Space/Tab 也可执行相应动作 | 按实际已有上下文启用动作，继续完全委托 Herdr |
| 系统快捷键 | 终端会截获退出/设置 | 将 ⌘Q / ⌘, 交回 AppKit 菜单 |
| 旧版兼容 | 快照失败后走多次旧 RPC | 删除 fallback；非法/缺失 snapshot 原样报告 |

## 保留的边界

不引入 Herdrm 文件树、目录浏览、文件预览或上传界面。没有复制工具默认的绕过权限参数。SSH 继续使用系统 SSH/config/keys；Keychain 密码登录、Tailcat 密钥管理、Tailscale 认证、多语言、细笔画/字体粗细、Ghostty 配置导入及附件粘贴仍有差距，本轮没有宣称完整功能对齐。更多功能应优先使用上游已有契约。

## 验证证据

- Brew 实际安装 v0.1.2；包版本、签名完整性和 universal 架构检查通过。macOS 因 ad-hoc 拦截后仅移除本 App quarantine；实际本地命令输出、分屏与正常冷启动通过，没有关闭全局 Gatekeeper，也未输入管理员密码。
- 10 项核心测试通过，包含参数边界/未闭合引号/不执行 shell 展开、快照错误不被旧版 fallback 隐藏；4 项发布契约检查通过。
- 独立临时 Herdr 实例实际验证 `integration.list`、`workspace.create`、`workspace.rename`、`tab.create`、完整 snapshot；测试服务器已停止，未改动用户服务端会话。
- 原生 Debug 与 universal Release 构建通过。实际截图检查新建表单、主界面、搜索、终端预览、通知设置，⌘B 隐藏/恢复侧栏通过；终端聚焦时 ⌘, 打开设置、⌘Q 退出进程通过。
- 真实远端 SSH 断线重连、Agent 完整启动等待、通知投递后点击、Intel 实机和 macOS 14 尚未验收。截图不等同于这些运行证据。
