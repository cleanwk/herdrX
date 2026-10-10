# Architecture

HerdrX 是 Herdr 的原生客户端。Herdr 是服务端会话拓扑与插件行为的权威；GUI 持有当前选择、连接状态和可复用的终端表面。目录按实际职责组织，不沿用参考蓝图的类名和插件 SDK。

## 边界

| 位置 | 责任 |
| --- | --- |
| `Core/Sources/HerdCore` | Foundation 数据模型、NDJSON RPC、事件订阅、快照事务和搜索 |
| `Core/Sources/PTY` | `forkpty`、`execve`、前台进程 CWD 的薄 C 桥 |
| `App/Desk.swift` | 设备连接、选择、缓存、会话操作、通知与布局 |
| `App/PTY.swift` | 串行异步读写、读写与退出代次、关闭与回收 |
| `App/Terminal.swift` | Ghostty 原生表面、IME、绘制可见性和分屏画布 |
| `App/Workbench.swift` | 工作台布局与搜索；Sidebar/Tabs/Commands 分别封装行、标签和原生命令 |
| `App/Extensions.swift` | Herdr 插件动作、启停、日志和面板的原生呈现 |
| `scripts` / `distribution` | 构建、公证、发布元数据与现有 tap 的同步逻辑 |

## 控制与字节

RPC 负责创建、分屏、布局和拓扑。每个请求使用独立 Unix socket，完整匹配响应 ID，拒绝超限或截断帧。事件连接独立存在，事件只作为失效信号；读到信号后重新读取服务端快照，不将旧事件覆盖到新快照。单个缓存信号合并突发事件，刷新期间的新信号会触发下一次读取。Pane 集合变化后重建带具体 Pane ID 的状态订阅。事件丢失或断线后通过完整快照恢复并重新订阅；无事件期间每 10 秒校准。连接失败按 1–30 秒退避重试，SSH 失败重建隧道，不自动抢回被接管的终端。

PTY 负责原始 ANSI 字节。读写在串行 IO 队列上执行，直接连接 Ghostty 的 in-memory session，字节不进入 `@Published`。慢输入通过非阻塞写源排队；过量输入明确提示。子进程启动使用 C 桥，避免在 fork 后调用 Swift 分配器。关闭请求异步完成，先发送 SIGHUP，未退出的本地 attach 在两秒后回收。

## 身份与生命周期

终端缓存唯一使用 `DeviceID + PaneID`，不随 Agent 检测状态改变。独立 Shell 使用客户端所有的 pane key，不保证服务器会话持久性。Agent attach 使用 Pane ID，普通终端 attach 使用 Terminal ID。每次 PTY 启动都有代次；旧进程 read/write/exit 都受当前 run 保护，旧退出回调无法结束新 attach。被其他客户端接管后不自动抢回。

RPC 连通、attach 存活、表面可见及 Agent 状态分别保存。断线只更新对应设备的错误，保留最后完整快照。旧请求完成后会检查取消状态与刷新 token，避免覆盖更新的读取或重新插入已删除设备。

每个 SSH 命名会话有单独的随机本地 socket。SSH 连接不扫描凭据、不创建密钥，认证和主机信任交给系统 SSH。隧道启用连接超时与 keepalive；每次尝试独立拥有 socket 和诊断文件，取消旧连接不会清理新连接。断开时清理自身创建的 socket。设备描述符只保存名称和连接参数。

关闭 GUI 或忘记连接不调用服务器 `pane.close`。只有用户明确关闭服务器 Pane 才调用该方法。当前选中的服务器标签才创建 attach；已创建的表面切换后仍然挂载。隐藏表面暂停绘制、释放 drawable 并保留尺寸，不因其他标签的几何变化修改后台 PTY 的 viewport。

## 快照与扩展

`session.snapshot` 的工作区、Tab、Pane 关系完整验证后才能发布。只支持当前 `session.snapshot` 契约，缺失或非法快照直接报告错误，不隐藏错误或请求旧版接口。

插件使用 Herdr 的 `plugin.list`、`plugin.enable/disable`、`plugin.action.invoke`、`plugin.log.list` 和 `plugin.pane.open`。GUI 不执行插件命令。Herdr 的弹出面板不提供可 attach 的 Pane ID，因此 GUI 明确提供 Open in Tab，并通过原生支持的 placement 覆盖打开。

`agent.view.set` 属于 Herdr 内置 Agents 视图的声明式投影，上游快照不返回该投影；本客户端不伪造它。普通 Pane 的 title、state_labels 和 workspace tokens 可直接呈现。未来上游暴露新的 GUI 能力时，再增加相应渲染适配。

## 当前边界

2026-10-10 的后续 UX 审计与用户补充已覆盖旧复刻范围：移除 Agent 启动器、文件树、预览、传输、附件投递及独占服务。`CommandProcess` 仅供连接发现与 Git 元数据读取，不包含文件传输 API。普通终端文本粘贴仍交给 Ghostty。原有偏好键保持惰性，不清理用户文件。Tailcat 使用独立 Go helper 将控制端口 6464/终端端口 6465 桥接到私有 Unix socket，令牌经 stdin 传入、身份和令牌存于 HerdrX 独立 Keychain service；未获得真实 host，所以源码和 universal 构建通过不代表真实连接已验收。没有额外的 Schema 表单、ACC 提供商或插件市场。

终端兼容性沿用固定版本的 Ghostty，并实现空闲 IME 插入点、Kitty 模式恢复和隐藏尺寸守卫。未复制参考项目的 ANSI 颜色改写器；Pi 等 Agent 的浅色光标及第三方语音输入法仍需要真实环境验收。本次运行与性能证据以 `docs/parity/STATUS.md` 及其 evidence 为准，不沿用参考项目历史指标。

Agent 创建读取 `integration.list` 的 available 工具，不再硬编码 CLI。参数解析为 argv，不作 shell 展开；默认工具执行交给 `agent.start`。本机显式命令覆盖经登录 PATH 检查和 shell 参数引用后写入新 Pane，再等待服务端识别；本机覆盖不会传给远端。快速新空间读取目标 Pane 的当前目录，使用 `workspace.create` 并选择返回的 Space；高级表单保留明确设备、名称和目录。通知仅由 Agent 状态转换产生，携带设备与 Pane 路由；当前正在看的 Agent 不提醒。

客户端注意力由 HerdCore.Attention 管理，与通知开关分离。TabOrder 保存以相邻 Tab 为锚点的意图队列，串行提交失败后只移除失败操作，后续意图继续投影。文件浏览器以根代次与预览请求 ID 丢弃过期结果。

## 构建与验收

`project.yml` 保留 SwiftUI/AppKit、HerdCore 和固定 Ghostty 依赖。Tailcat helper 使用 Go modules，`scripts/tailcat.sh` 构建 arm64/x86_64 后 lipo 合并，由 Xcode post-build 打包并签名。新构建依赖 Go（go.mod 指定工具链），SSH 文件服务依赖目标 Python 3。文件传输不经过终端输入或 Herdr RPC。第三方许可归档在 Resources/Licenses/Tailcat。

DEBUG 可通过 `HERDRX_STATE_DIR` 隔离设备存储，`HERDRX_WINDOW_SIZE` 指定验证窗口，`HERDRX_DIAGNOSTICS` 输出 surface 身份和可见/隐藏 frame；正式运行不会默认记录这些诊断。验收只操作独立命名会话和私有 SSH fixture，不连接已有用户工作 Pane。原生事件、截图、纯状态测试与源码审查分开标记，不能相互替代。

## 本轮交互规则

标题投影、精确快捷键匹配、搜索稳定选择和相邻标签回落放在 HerdCore 的小型纯模型中。搜索索引复用未变化名称/上下文的拼音缓存；AppKit NSTextField 处理方向键和 Return，并先尊重 marked text。Desk 的写操作锁按设备与对象/意图区分，导航不因其他对象忙碌而锁住。创建和插件动作捕获原目标；显式导航有焦点版本号，后台快照和布局不主动抢 first responder。

高级创建与搜索取消恢复原焦点；显式选择目标时恢复新目标。服务器关闭确认显示设备、名称与受影响 Pane 数。本机关闭通过前台进程组和 shell 身份检查，对运行或无法确认空闲的进程显示确认。隐藏应用只暂停表面绘制，保留 attach；不在恢复时自动接管其他客户端。
