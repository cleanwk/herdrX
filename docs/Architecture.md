# Architecture

HerdrX 是 Herdr 的原生客户端。Herdr 是服务端会话拓扑与插件行为的权威；GUI 持有当前选择、连接状态和可复用的终端表面。目录按实际职责组织，不沿用参考蓝图的类名和插件 SDK。

## 边界

| 位置 | 责任 |
| --- | --- |
| `Core/Sources/HerdCore` | Foundation 数据模型、NDJSON RPC、事件订阅、快照事务和搜索 |
| `Core/Sources/PTY` | `forkpty`、`execve`、前台进程 CWD 的薄 C 桥 |
| `App/Desk.swift` | 设备连接、选择、缓存、会话操作、通知与布局 |
| `App/PTY.swift` | 串行异步读写、进程退出代次、关闭与回收 |
| `App/Terminal.swift` | Ghostty 原生表面、IME、绘制可见性和分屏画布 |
| `App/Workbench.swift` | 侧栏、原生标签、快捷键与搜索 |
| `App/Extensions.swift` | Herdr 插件动作、启停、日志和面板的原生呈现 |
| `scripts` / `distribution` | 构建、公证、发布元数据与现有 tap 的同步逻辑 |

## 控制与字节

RPC 负责创建、分屏、布局和拓扑。每个请求使用独立 Unix socket，完整匹配响应 ID，拒绝超限或截断帧。事件连接独立存在，事件只作为失效信号；读到信号后重新读取服务端快照，不将旧事件覆盖到新快照。单个缓存信号合并突发事件，刷新期间的新信号会触发下一次读取。Pane 集合变化后重建带具体 Pane ID 的状态订阅。事件丢失、断线或不支持订阅时通过完整快照恢复并重新订阅；无事件期间每 10 秒校准，兼容旧服务时每 2 秒降级刷新。

PTY 负责原始 ANSI 字节。读写在串行 IO 队列上执行，直接连接 Ghostty 的 in-memory session，字节不进入 `@Published`。慢输入通过非阻塞写源排队；过量输入明确提示。子进程启动使用 C 桥，避免在 fork 后调用 Swift 分配器。关闭请求异步完成，先发送 SIGHUP，未退出的本地 attach 在两秒后回收。

## 身份与生命周期

终端缓存唯一使用 `DeviceID + PaneID`，不随 Agent 检测状态改变。Agent attach 使用 Pane ID，普通终端 attach 使用 Terminal ID。每次 PTY 启动都有代次；旧进程的退出回调无法结束新 attach。被其他客户端接管后不自动抢回。

RPC 连通、attach 存活、表面可见及 Agent 状态分别保存。断线只更新对应设备的错误，保留最后完整快照。旧请求完成后会检查取消状态与刷新 token，避免覆盖更新的读取或重新插入已删除设备。

每个 SSH 命名会话有单独的随机本地 socket。GUI 不扫描凭据、不创建密钥，认证和主机信任交给系统 SSH。断开时清理自身创建的 socket。设备描述符只保存名称和连接参数。

关闭 GUI 或忘记连接不调用服务器 `pane.close`。只有用户明确关闭服务器 Pane 才调用该方法。当前选中的服务器标签才创建 attach；已创建的表面切换后仍然挂载。隐藏表面暂停绘制、释放 drawable 并保留尺寸，不因其他标签的几何变化修改后台 PTY 的 viewport。

## 快照与扩展

`session.snapshot` 的工作区、Tab、Pane 关系完整验证后才能发布。不支持快照时依次请求 workspace.list、tab.list、workspace 范围内的 pane.list，全部成功并验证拓扑后一次发布；无布局的旧服务降级为等宽排列。

插件使用 Herdr 的 `plugin.list`、`plugin.enable/disable`、`plugin.action.invoke`、`plugin.log.list` 和 `plugin.pane.open`。GUI 不执行插件命令。Herdr 的弹出面板不提供可 attach 的 Pane ID，因此 GUI 明确提供 Open in Tab，并通过原生支持的 placement 覆盖打开。

`agent.view.set` 属于 Herdr 内置 Agents 视图的声明式投影，上游快照不返回该投影；本客户端不伪造它。普通 Pane 的 title、state_labels 和 workspace tokens 可直接呈现。未来上游暴露新的 GUI 能力时，再增加相应渲染适配。

## 当前边界

按用户要求，宿主不内置文件树、目录浏览、预览或传输。设备支持本机与 SSH；Tailcat 桥没有可验证的契约，不能执行终端动作。没有额外的 Schema 表单、ACC 提供商或插件市场。

终端兼容性沿用固定版本的 Ghostty，并实现空闲 IME 插入点、Kitty 模式恢复和隐藏尺寸守卫。未复制参考项目的 ANSI 颜色改写器；Pi 等 Agent 的浅色光标及第三方语音输入法仍需要真实环境验收。运行与性能证据只以 Validation 记录为准，不沿用参考项目历史指标。
