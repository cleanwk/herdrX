# ACCM → HerdrX 交付与验收记录

日期：2026-10-10。基线：`0fe3b8456`（v0.1.3）；分支：`codex/workbench-parity`。原始需求完整保存在 [SPEC.txt](SPEC.txt)，匿名夹具在 [fixture.json](fixture.json)。本提交是可构建、可运行的原生实现，**不是 C01–C32 全部通过的验收声明**。

## 交付环境与证据口径

实测 macOS 27.0.1 / Apple Silicon，Xcode 27.0，Swift 6.4，Herdr 0.9.3；完整环境见 [environment.json](evidence/environment.json)。最终 Release 为 arm64+x86_64 universal，ad-hoc 本地签名校验通过；没有安装到 Applications、发布、推送或公证。

控制与终端测试只使用 `herdrx-parity-20261010`、`herdrx-parity-ssh-20261010` 两个独立命名会话，及 `/tmp/herdrx-fixture`。SSH 为 127.0.0.1:42891 独立 sshd、独立密钥/config/known_hosts，保留严格 host-key 检查；它验证 SSH 传输路径，不能替代真实跨机器网络条件。Debug app 使用独立 `.dev` bundle 与 `HERDRX_STATE_DIR`，没有读取用户保存的设备。截图中的 Agent 状态和 model/context 是明确报告的合成夹具；Pane 与 PTY 是真实进程，不代表运行了真实 Codex/Claude 工作。

“实现”描述代码和可运行入口；“验收”只描述实际证据。C 表只使用 PASS / FAIL / NOT RUN；有部分证据但未覆盖整条合同的条目仍记 NOT RUN，并列出已验证部分。没有运行的断言不能由源码、构建或截图替代。

## F01–F24 功能交付矩阵

| ID | 实现情况 | 落点与剩余边界 |
|---|---|---|
| F01 窗口 | 已实现 | 单一 28pt 集成栏，固定侧栏头尾，无底部状态条；980×620、1440×900 实拍与 frame 记录。 |
| F02 侧栏 | 已实现，部分待验收 | 260pt 初始、200–480pt、7pt 命中、双击复位、持久宽度；可折叠吸顶分组。长列表吸顶/折叠完整事件序列待补。 |
| F03 Space 行 | 已实现，部分待验收 | 两行分支占位、30秒缓存、路径 tooltip/复制、hover/选中、拖动及对象菜单；拖动所有失败路径待测。 |
| F04 Agent 行 | 已实现 | 跨 Space、状态形状、工具图标、设备归属、有界可选统计；普通终端按当前设备+Space 缩小；无模型数据时不造数。 |
| F05 Tab | 已实现，部分待验收 | 40–200pt 自适应、hover、横滚、重命名/关闭、左右半边插入、串行排序与单操作回滚、Pane 焦点记忆；原生连续拖动故障注入待补。 |
| F06 Pane | 已实现，部分待验收 | 内嵌等宽标题/上下文、焦点边框、hover/VoiceOver close、zoom restore、对象菜单；VoiceOver 实操与旧系统窗口边角待验收。 |
| F07 新 Space | 已实现并实测 | 本机与 SSH 当前 cwd、禁重复、仅创建默认 Tab/Pane；高级表单保留。 |
| F08 Agent 创建 | 已实现，竞态待验收 | 目标 integration.list、设备/Space/cwd、argv、加载/失败状态、按设备取消旧请求、启动失败保留输入；可控延迟 RPC 回归待补。 |
| F09 搜索 | 已实现，部分待验收 | 缓存名称/设备/目录/分支、中文全拼/无空格全拼/首字母，前缀→词首→子串→上下文；同层类型/注意力/本次客户端选择时间；50项。440/44/36/28pt 布局，完整键盘/删除竞态待测。 |
| F10 注意力/通知 | 已实现，通知待验收 | 首快照安静、非done→done未读、离开已观看行清除、删除清除；聚合与排序分离；系统通知点击/权限实测待补。 |
| F11 主题/语言 | 部分完成 | Default/Catppuccin/Dracula/Nord、外观、强调色、中英主要界面、surface保留；Follow Herdr 只解析已支持主题族，不能导入任意主题token。少数动态错误/AX说明仍为英文或系统语言，完整文案矩阵未闭环。 |
| F12 终端设置 | 已实现，部分待验收 | 字体9–22pt/0.5步进、字重、行距、细笔画、鼠标、复制、一次导入；SF Mono Regular/Bold 原生预览实拍。导入失败与所有开关组合待测。 |
| F13 Agent 配置 | 已实现，部分待验收 | 10种工具覆盖、Automatic、登录PATH说明与本机预检；远端不使用本机覆盖。真实各CLI启动待验收。 |
| F14 文件区 | 已实现，部分待验收 | 默认隐藏、懒加载、隐藏文件、刷新、2MiB限制、拒绝符号链接/不支持类型、文本/图片原因提示、宽窄模式、代次丢弃；慢请求故障注入待补。 |
| F15 文件管理 | 已实现，部分待验收 | 双端列表/路径/历史/上级/大小/修改时间，单文件上传下载、冲突策略、进度/取消与临时文件清理；真实外网断线和面板竞态待补。 |
| F16 本机/SSH设备 | 已实现，部分待验收 | CRUD、发现命名会话、导入enabled机器、原配置保护、SSH config和可选port；隔离SSH实际连接/路由通过。批量导入与认证取消待测。 |
| F17 Tailcat | 已实现，未验收 | Go helper执行桥接，独立Keychain、令牌stdin、公钥和重生成确认、重试；universal helper已打包。没有真实host/token，不报告连通通过；文件操作明确不支持。 |
| F18 连接/会话 | 保留并增强，部分待验收 | 每设备独立连接代次、旧刷新拒绝、快照保留、认证失败不自动循环、显式隐藏1.5秒后释放attach；端到端断线/接管场景待测。 |
| F19 输入/选择/链接 | 保留并补实现，未完整验收 | Ghostty IME保留；TUI本地选择、12pt边缘扩选、链接菜单、无副作用模式恢复与显式中断分开。中文候选/语音/TUI/OSC8组合待原生实测。 |
| F20 附件 | 已实现，未端到端验收 | 按能力选择clipboard/path，图片PNG、文件路径、SSH唯一暂存、失败保留源；目标身份/设备复核；未知能力报原因，不宣称发送成功。 |
| F21 性能/隐藏 | 部分完成 | surface复用、隐藏frame守卫、20轮真实PTY代次回归；尚无同机400Agent投影与12Tab/24surface的前后p50/p95/CPU/RSS/resize基线，不能宣称无回退。 |
| F22 菜单/AX | 已实现，部分待验收 | 原生FocusedValue Commands替代隐藏按钮、命中对象菜单、Sheet Cmd-W守卫、关闭说明；VoiceOver完整审计和所有快捷键组合待补。 |
| F23 Herdr扩展 | 保留，运行待验收 | 原生plugin list/actions/log/Open in Tab路径保留，现有模型测试通过；没有创建新桌面插件运行时。独立插件完整回归待补。 |
| F24 身份/更新/关于 | 已实现，渠道待验收 | HerdrX名称/version/build、About、许可归档、Brew与条件Sparkle保留；未发布/安装，实际升级链路不在本次通过范围。 |

## T1–T7 阶段交付

| 阶段 | 当前出口 |
|---|---|
| T1 | 原生窗口、侧栏、Pane chrome 和可真实输入工作台已交付；尺寸/缩放、首启Shell有证据。 |
| T2 | 对象动作、状态、搜索、焦点、快速Space已接真实Herdr；未读/排序有纯状态测试，竞态及全菜单矩阵仍待补。 |
| T3 | 主题/终端/Agent/通知设置已可运行；界面主要中英双语，动态文案与权限矩阵仍待补。 |
| T4 | 本机/SSH浏览及传输完成，边界/冲突/取消有自动测试；UI慢请求故障注入待补。 |
| T5 | 设备管理和Tailcat执行桥已实现；SSH实际路由通过，Tailcat真实host验收待提供环境。 |
| T6 | PTY代次与隐藏尺寸守卫已验证部分；原生输入法/TUI和完整性能基线未达到最终出口。 |
| T7 | 逐项矩阵、截图、许可证、universal构建和本地commit交付；整体验收仍开放。 |

## C01–C32 验收结果

| ID | 结果 | 实际证据与未验证断言 |
|---|---|---|
| C01 | PASS | 两尺寸 [浅色](screenshots/workbench-light-980.png)/[深色](screenshots/workbench-dark-1440.png)，[surface frame](evidence/surfaces.jsonl)；独立复核确认无工具栏遮挡/标题裁切。 |
| C02 | PASS | [sidebar-width.json](evidence/sidebar-width.json)：真实正反拖200/480、重启480、双击260。原始中间布局估算720单列说明，非持久宽度。 |
| C03 | NOT RUN | Cmd-B隐藏/恢复及固定头尾已观察，[恢复AX](evidence/sidebar-restore.txt)。长列表吸顶+折叠完整事件序列未验证，滚动尝试不足以证明通过。 |
| C04 | NOT RUN | 三Pane标题/焦点可见，关闭按钮AX有对象名；VoiceOver实际关闭未执行。 |
| C05 | PASS | 空设备配置真实命令返回 `NO_HERDR_SHELL_OK`：[截图](screenshots/first-launch-shell.png)、[AX/环境](evidence/first-launch-shell.txt)。无Herdr连接；宿主仍安装Herdr二进制，未做卸载。 |
| C06 | PASS | [device-routing.json](evidence/device-routing.json)：两设备同w1:p1，点击SSH Agent后原生输入sentinel仅在SSH服务端回读，跨Space Agent保留。 |
| C07 | PASS | [Core测试](evidence/final-core.txt)，AttentionTests：状态rank与unread/working聚合分离；blocked优先实现，稳定拓扑排序。 |
| C08 | PASS | AttentionTests：初done不未读、working→done、跨设备隔离、离开清除、离开done/删除清除；选中离开由Desk接线。 |
| C09 | NOT RUN | needsAttention筛选有测试；系统通知点击、权限/真实跳转组合未运行。 |
| C10 | PASS | [本机](evidence/quick-space.json) / [SSH](evidence/quick-space-ssh.json)：原生快速创建前后仅增加1 Space、1 Tab、1 Pane，cwd来自相应设备。 |
| C11 | NOT RUN | 按设备.task取消和禁重复已实现；未构造可控延迟integration RPC及失败参数保留事件序列。 |
| C12 | NOT RUN | TabOrder失败首操作保留后续意图测试通过；RPC重排smoke通过。原生左右半边连续拖动+服务端失败组合未运行。 |
| C13 | NOT RUN | [菜单AX](evidence/context-menu.txt)、[关闭确认](evidence/context-target.txt)验证选中A右键B、B对象/设备、无选区复制禁用；未逐一执行所有菜单动作。 |
| C14 | NOT RUN | [Sheet Cmd-W](evidence/sheet-close.txt)只关Sheet；[原生Cmd-D](evidence/native-split.json)只给独立w3新增1Pane。全部Close上下文和命令启用矩阵未遍历。 |
| C15 | NOT RUN | Core测试覆盖全拼/首字母、名称优先、目录/分支/设备、50项与400项查询；完整键盘滚动和删除目标竞态未执行。 |
| C16 | NOT RUN | [主题surface身份](evidence/theme-surface.json)与默认浅色/Catppuccin深色实拍通过；全部外观×配色×强调色组合未遍历。 |
| C17 | NOT RUN | [Regular](screenshots/settings-terminal-zh.png)/[Bold](screenshots/settings-terminal-bold.png)真实预览变重；字体开关、导入失败全组合未执行。 |
| C18 | NOT RUN | 中文工作台/设置实拍；主要字符串有en/zh资源。动态错误/AX残留英文及完整英文/长文案/减少动态效果矩阵待补。 |
| C19 | NOT RUN | argv既有测试通过，本地覆盖与远端代码路径隔离；各CLI和拒绝通知权限恢复没有真实运行证据。 |
| C20 | PASS | [files-surface.json](evidence/files-surface.json)：开关前后surface identity一致、可用画布差321pt（320文件+1边界）；窄栏返回按钮实际可见。 |
| C21 | NOT RUN | FileTests通过0/2MiB/2MiB+1、hidden、symlink；文本实读成功。懒加载事件及图片/二进制/解码失败UI完整边界未运行。 |
| C22 | NOT RUN | 根generation与preview UUID守卫已实现；未构造旧慢请求晚到故障注入。 |
| C23 | NOT RUN | 本地三冲突策略、取消保留原文件、part清理；SSH上传/下载、cancel/keepBoth、取消保留及清理已通过。SSH replace成功/网络中断及UI全流程尚未全部覆盖。 |
| C24 | NOT RUN | 实际SSH配置别名/命名socket/跨设备路由通过；发现与空导入路径已运行。完整新增/编辑/移除/批量导入失败矩阵未跑完。 |
| C25 | NOT RUN | 设备独立代次、认证失败停止重试与快照保留实现；未主动注入断网、认证取消与attach被接管。 |
| C26 | NOT RUN | 无独立Tailcat host/token；helper universal编译成功，`go test`仅编译且无测试文件。没有真实终端输入证据。 |
| C27 | NOT RUN | 普通原生Shell键入和SSH投递通过；中文组字、语音、TUI选字、OSC8/折行链接、真实Agent图片能力未组合实测。 |
| C28 | NOT RUN | 12pt持续扩选及松手/隐藏/非key窗口停止已实现；未执行完整原生拖选边缘事件。 |
| C29 | NOT RUN | [hidden-grid.json](evidence/hidden-grid.json)74次去重后的隐藏frame比较保持；[20轮真实PTY](evidence/final-pty.txt)无旧代输出。可见未聚焦输出、Cmd-H释放/恢复、takeover全生命周期仍待测。 |
| C30 | NOT RUN | 基线与改后Core查询有日志，但不是整机性能基线。400Agent投影、12Tab/24surface及p50/p95/CPU/RSS/resize计数尚未运行。 |
| C31 | NOT RUN | 原生扩展记录/参数等既有回归通过，无ACC业务入口；独立测试插件的动作/日志/Open in Tab未实际运行。 |
| C32 | NOT RUN | universal构建、签名验证、HerdrX bundle/版本/许可与About实现已确认；Brew/Sparkle安装升级、真实Keychain和完整辅助功能矩阵未执行。 |

## 可重跑命令

```sh
swift test --package-path Core -c release
python3 -m unittest discover -s scripts -p 'test_*.py'
scripts/test-pty.sh
scripts/test-ssh.sh
(cd Tools/Tailcat && go test ./...)
scripts/build.sh
```

本次17项Core测试含隔离SSH（未配置时该项会明确skip）。`scripts/test-ssh.sh`自动生成loopback sshd/密钥/config，执行同样测试并清理；无需现有凭据，端口42891和build/ssh-fixture目录须空闲。手动fixture也可以这样运行：

```sh
HERDRX_TEST_SSH_CONFIG="$PWD/build/ssh-fixture/config" swift test --package-path Core -c release
HERDRX_TEST_SSH_CONFIG="$PWD/build/ssh-fixture/config" scripts/build.sh
```

手动SSH测试依赖私有`parity-fixture` alias与本地42891 sshd；不把测试私钥提交到仓库。原手动fixture已停止，配置移到忽略的build/parity-intermediate-logs内；重跑推荐`scripts/test-ssh.sh`。`scripts/parity_smoke.py`只接受`herdrx-parity-*`路径，创建新对象，重复执行会再创建一套：

```sh
python3 scripts/parity_smoke.py --socket /absolute/path/to/sessions/herdrx-parity-NAME/herdr.sock --output /tmp/herdrx-smoke.json
```

最终日志：[Core 17/17](evidence/final-core.txt)、[Python](evidence/final-python.txt)、[PTY](evidence/final-pty.txt)、[Release build](evidence/final-release-build.txt)。输出：`build/release/Build/Products/Release/HerdrX.app`。只有AppIntents元数据未提取的构建提示；项目无该框架依赖。

## 截图与独立界面复核

原生CUA截图，2× scale，不裁切/重绘；系统共享指示器与指针光圈不是应用UI。工作台均SF Mono 13pt Regular，字重比较单独使用Bold：

- [980×620pt 默认浅色](screenshots/workbench-light-980.png)：320pt窄文件预览。
- [1440×900pt Catppuccin深色](screenshots/workbench-dark-1440.png)：560pt文件区、210pt树。
- [中文终端设置](screenshots/settings-terminal-zh.png)与[Bold对照](screenshots/settings-terminal-bold.png)。设置内容布局740×560pt；macOS原生窗口实际为740×648pt。
- [空设备首启Shell](screenshots/first-launch-shell.png)。

Impeccable独立reviewer第一次要求修正工具栏遮挡、等宽预览、Agent工具图标及旧设计文档；第一次verdict四项解决，又发现标题裁切。第二次verdict确认裁切解决、工具栏保持可见，`disposition: ship`只覆盖这些视觉修正，不是全功能通过。独立documenter已更新根DESIGN.md与.impeccable/design.json的实际token和布局。

## 实现限制与后续验收输入

- Tailcat需要真实可丢弃host/token及allowlist；当前代码不保存虚假connected状态。Go工具链是新增构建依赖，SSH文件端需要Python3。
- 原生IME/语音/TUI/附件、通知授权、VoiceOver、低版本macOS和Intel实际运行仍需相应环境。universal编译不等于Intel运行通过。
- Follow Herdr解析是受支持主题族映射；自定义token不完整。语言主要界面完成，动态诊断和少数AX说明仍需本地化。
- 性能比较与RPC/UI竞态故障注入是仍未完成的验收工作，不能用“源码有守卫”替代。
- 没有ACC账号/订阅/SIM/Code Studio/内部更新源，也没有额外插件运行时。保留HerdrX品牌和原发布渠道。

协议依据：[Tailcat上游](https://github.com/tailscale/tailcat/blob/main/README.md)、[Herdr Tailcat适配接口](https://github.com/missuo/herdrm/tree/main/Packages/HerdrTailcat)、[Ghostty选择命令](https://ghostty.org/docs/config/keybind/reference)、[Herdr机器配置](https://github.com/herdrdev/herdr/blob/master/src/cli/machine.rs)。使用公开协议事实独立实现；第三方依赖许可位于Resources/Licenses/Tailcat和Resources/Notices.txt。

验收后已停止两个独立Herdr server和手动fixture sshd；测试应用已退出。自动SSH测试脚本退出时清理自己的sshd与临时密钥。没有停止用户现有会话。
