# C01–C90 本轮验收

2026-10-10。PASS 仅用于本轮已运行且满足记录范围的场景。NOT RUN 表示完整场景尚无本轮运行证据（证据栏可记录已通过的模型或部分操作），不等于实现失败。全部副作用只在 herdrx-ux-* 隔离会话。

| ID | 场景 | 结果 | 本轮证据 / 限制 |
| --- | --- | --- | --- |
| C01 | 新安装、已有偏好升级后分别启动 | NOT RUN | 生产源码与精确快捷键测试确认新建 Agent、文件树、预览、传输和附件投递入口已删除；历史 SPEC 保留原文。  全新安装与旧偏好升级两种完整安装流程未重跑。|
| C02 | 依次检查主菜单、右键、工具栏、搜索、设置与快捷键 | PASS | 源码删除路由与菜单/设置核对，精确快捷键测试通过；README/PRODUCT/Architecture已同步。历史SPEC不作为当前路由。 |
| C03 | 终端手动启动一个受支持Agent，再退出 | NOT RUN | 界面使用 pane.report_agent 合成状态；尚未运行真实 Agent CLI 检测闭环，不能据此宣布识别通过。 |
| C04 | 无Herdr服务、已有Herdr服务分别启动 | NOT RUN | 空启动的 Shell 可用；已移除组件、菜单、快捷键和消费者；旧偏好无读取点。 |
| C05 | 980×620、1200×760、1440×900、超宽窗口 | NOT RUN | 本轮原生 980×620 浅色与 1440×900 深色截图；保持 28pt 单栏。  尚未覆盖超宽窗口。|
| C06 | 侧栏拖到200/260/480，双击复位，重启 | NOT RUN | 200/260/480 启动宽度有本轮截图；拖动/双击/持久化全链未重跑。一次 AX 调整因 CLI 覆盖固定宽度未生效，未记为通过。 |
| C07 | 隐藏/显示侧栏，Tab多到溢出 | NOT RUN | Tab 自动可见已操作；侧栏隐藏与所有溢出组合未覆盖。 |
| C08 | 空设备组/无Agent/无普通终端 | NOT RUN | B 设备空组可创建；离线设备就地报错；当前截图有相应状态。 |
| C09 | 多设备多Space滚动，折叠后重启 | NOT RUN | 400 行滚动已操作；折叠后重启恢复未重跑。 |
| C10 | 新建Space左入口、Tab顶部加号、分屏菜单 | PASS | 截图与设备 B 原生创建操作确认空间/标签/分屏入口职责分离。 |
| C11 | Pane自定义名、Tab自定义名、OSC标题、工具名同时存在 | NOT RUN | model证据： UXTests 标题优先级；本轮服务器关闭确认、搜索和 Pane 使用同名；不等于所有 OSC 原生组合已测。 |
| C12 | 中文32字、英文80字符、Emoji、混合路径 | NOT RUN | 中文长名和混合路径在截图中有截断与完整 help；80 英文/Emoji 全组合未执行。 |
| C13 | 标题为空、全空格、换行、未知工具 | NOT RUN | model证据： UXTests 空白/换行/通用工具命令过滤；unknown 使用独立文字/轮廓图标，未做全部原生组合。 |
| C14 | 两设备相同Space/Tab/Pane ID且同名 | NOT RUN | 双元数据设备使用相同 ID 的 400 行测试正常；右键/关闭所有路径未用重 ID 服务器副作用验证。 |
| C15 | 200/260/480pt侧栏查看同一Agent | PASS | 本轮 200/260/480 三个原生截图，同一 Agent 状态保留尾部。 |
| C16 | 运行/等待输入/完成未读/完成已读/空闲/未知并列 | NOT RUN | 合成元数据包含五状态，真实界面截图验证工作与等待；完成已读/未读并列全矩阵未执行。 |
| C17 | 首次快照全是done | NOT RUN | model证据： Attention 回归用例覆盖安静首快照；原生系统通知未运行。 |
| C18 | 非done→done，当前行选中与未选中分别执行 | NOT RUN | model证据： Attention 状态测试覆盖未读、当前观看与离开；系统通知未运行。 |
| C19 | done→working、删除Pane、断线后恢复 | NOT RUN | model证据： Attention 测试覆盖清理与设备隔离；真实断网重连未运行。 |
| C20 | 同一Space同时有blocked、working、unread done | NOT RUN | model证据： Attention 汇总与排序测试通过。 |
| C21 | 连续⌘⇧J，有/无待处理项、跨Space | NOT RUN | 保留注意力循环与 reveal 路由；未完整操作有/无候选跨空间循环。 |
| C22 | 无metadata、只有model、长account、未知token | NOT RUN | source证据： 无 metadata 占位、无配额仪表；仅实际 token 在 help 中展示。 |
| C23 | 非Git、Git分支、detached HEAD、读取失败/延迟 | NOT RUN | 真实 Git 分支已截图；非 Git、detached、超时失败和 stale 分支全组合未操作。 |
| C24 | 选中A，右键B，重命名/复制/关闭后取消 | NOT RUN | 菜单捕获 PaneKey，源码确认；选 A 右键 B 全套取消焦点序列未完成。 |
| C25 | 12个长Tab，用⌘1…9和前后切换 | PASS | 12 个 Tab，两轮 ⌘1–9 与后续三个 next，Tab9 改动前后截图；24-surfaces-tab-cycles.txt。 |
| C26 | 新建Tab、关闭首/中/末Tab、其他客户端删Tab | NOT RUN | model证据： 新增 NeighbourSelection 用例覆盖首/中/末删除和不改变仍有效选择；实际其他客户端删除序列未跑。 |
| C27 | 双击Tab、Enter提交、Esc取消、空白名称 | NOT RUN | 原生 NamePrompt 含就地空白校验；双击/Enter/Esc 全序列未运行。 |
| C28 | 拖Tab到左右半边、边缘、首尾、跨Space | NOT RUN | 拖动边缘滚动和跨 scope 取消已实现；鼠标左右半边/首尾全序列未运行。 |
| C29 | 连续两次重排，第一次RPC失败 | NOT RUN | model证据： TabOrder 原有意图队列/首失败保留后续测试通过；未注入真实慢 RPC。 |
| C30 | 单Pane变2/3/4，再关闭回1 | NOT RUN | 两个 Pane 和数量已截图；1→2→3→4→1 序列未全跑。 |
| C31 | 同工具两个Pane分别自定义名称 | PASS | 登录问题排查：侧栏、顶部、搜索、关闭确认同投影；真实 fixture pane.rename +截图。 |
| C32 | 向右/向下分屏、混合分屏、极端比例 | NOT RUN | 分屏/拖动最小尺寸与可见解释已实现；混合布局极端比例全矩阵未跑。 |
| C33 | 放大当前Pane、切Tab、还原 | NOT RUN | 保留 zoom/restore 并保证隐藏表面复用；完整交互序列未重跑。 |
| C34 | Tab A的右Pane→Tab B→Tab A | NOT RUN | Pane 记忆保持；左右 Pane 切换并删除完整序列未重跑。 |
| C35 | 空闲独立Shell与忙Shell分别⌘W | NOT RUN | partial native证据： 真实 sleep 45 的独立 Shell ⌘W 出现忙确认，Esc 取消；PTY 实测 idle/running/unknown。空闲 Shell UI 直接关闭未单独记录。 |
| C36 | 关闭Server Pane/Tab/Space，分别取消和确认 | NOT RUN | 服务器 Pane 取消实测，显示任务/设备/1个影响，快照仍25；Tab/Space 确认销毁组合未运行。 |
| C37 | 搜索/重命名/高级创建Sheet在前时⌘W | NOT RUN | 搜索 ⌘W 已关闭 Sheet 且主窗口保留；重命名/高级创建全部状态未运行。 |
| C38 | 关闭窗口或忘记设备连接 | NOT RUN | partial native证据： 多次只终止隔离 Debug 客户端，A 的25 Pane保留；忘记设备 UI 未单独测试。 |
| C39 | 2秒延迟下连点新建/分屏，期间切Tab | NOT RUN | 按对象/意图忙锁、创建捕获目标和焦点版本已实现；2秒延迟连点故障注入未完成。 |
| C40 | Pane hover、离开、VoiceOver启用 | NOT RUN | 关闭按钮具有对象 AX name 和预留槽；VoiceOver 实际遍历未运行。 |
| C41 | ⌘K打开即输入、Esc关闭、重新打开 | PASS | ⌘K输入、Escape/⌘W关闭，原生键盘搜索已操作；search-keyboard.txt。 |
| C42 | 汉字、全拼、无空格全拼、首字母、路径/分支 | NOT RUN | model/native subset证据： 纯搜索测试+400行原生 dlxf/denglu/数字/无结果输入；全部汉字/分支组合未运行。 |
| C43 | 0/1/8/50个结果、空查询 | NOT RUN | 默认有结果与无结果截图已记录，自适应高度；1/8/50 全档未截图。 |
| C44 | 连续按上下键到首尾，鼠标hover列表 | NOT RUN | NSTextField Down 原生实测通过；首尾越界与 hover 全序列未完成。 |
| C45 | 高亮项前插入/删除结果、状态排序变化 | NOT RUN | model证据： SearchSelection 插入/重排保持 ID 测试通过；原生状态注入未完成。 |
| C46 | 高亮对象被删除后立即Enter | NOT RUN | model证据： 高亮删除清空选择，不能 Enter 打开替代项测试通过；原生并发删除未完成。 |
| C47 | 筛选设备A后全局搜索设备B | NOT RUN | reveal 清除冲突筛选并展开目标组；跨设备筛选后实际跳转未完整操作。 |
| C48 | 查询时注入大量状态发布与分支更新 | NOT RUN | 400条索引重复输入与缓存复用已验证；高频状态/分支事件注入未覆盖。 |
| C49 | TextField输入中文组合中触发Return/方向键 | NOT RUN | 保留 marked text 委托防护；CUA Unicode输入不是 IME 候选操作，不作为证据。 |
| C50 | 键盘停在侧栏控件，触发快照刷新/窗口resize | NOT RUN | Canvas 仅显式 focusRevision 请求焦点；侧栏键盘焦点+实时刷新/resize 全序列未测。 |
| C51 | 设置窗口在前，主窗口状态不断更新 | NOT RUN | 设置可操作，主窗口焦点受 keyWindow/sheet guard；持续状态更新时输入未测。 |
| C52 | 打开Sheet后目标Pane被删除，再Esc | NOT RUN | 焦点书签与有效视图判断/失效回落已修；Sheet前台删除目标完整交错未跑。 |
| C53 | 菜单触发、快捷键触发同一动作 | NOT RUN | model/native subset证据： 精确键值+modifier 共用 enabled；原生 CmdW 修复后只显示正确 Pane确认；所有动作组合未跑。 |
| C54 | 删除功能的快捷键、额外modifier组合 | NOT RUN | model证据： UXTests 排除CmdN/CmdShiftE/F及额外修饰组合，CmdV交回文本终端。 |
| C55 | A在线/B离线，全部设备/仅B/独立Shell视角 | PASS | 本轮同屏A/B在线C离线，各组状态，独立Shell仍可操作。 |
| C56 | 点击B空组的创建Space，当前选中A | PASS | 原生点击B空组，实际B只新增1space/tab/pane，A未改变；target-and-cancel.json。 |
| C57 | 本机/SSH当前cwd快速创建Space | NOT RUN | 本机B创建cwd实际正确；快捷创建/SSH当前位置完整序列未跑。 |
| C58 | 高级Space名称空/路径相对/路径不存在/无权限 | NOT RUN | 名称/绝对路径校验，错误保留草稿；不存在/无权限服务器全部错误未执行。 |
| C59 | 连接失败但已有快照 | NOT RUN | 离线错误可见；已有快照后断开保留逻辑已实现，实际快照→断开序列未跑。 |
| C60 | 旧连接请求晚于新连接返回 | NOT RUN | 连接代次+路径+refreshID gate代码核对；真实晚响应故障未注入。 |
| C61 | SSH认证失败/host key失败 | NOT RUN | 认证/host key错误停止重试，显示终端认证提示；无专用远端失败fixture。 |
| C62 | 工作时掉网、重新上线 | NOT RUN | 未进行真实SSH掉网与attach恢复。 |
| C63 | 第二客户端接管，手动Reconnect | NOT RUN | 有显式接管确认；未进行两个客户端真实接管竞争。 |
| C64 | 编辑SSH自定义port/config→取消→新增 | NOT RUN | model证据： ConnectionDraft 从编辑完整重置，port/config不泄漏；UI全序列未执行。 |
| C65 | 忘记连接后重新添加同主机不同socket | NOT RUN | 设备身份隔离基础测试通过；忘记/重新添加同host不同socket UI序列未跑。 |
| C66 | 无Tailcat凭据/真实Tailcat环境分别验证 | NOT RUN | 无真实Tailcat host/凭据；helper构建不当连接通过。 |
| C67 | 普通键入、中英切换、组合输入、候选框 | NOT RUN | ASCII命令和中文粘贴可见；中英切换、组合候选完整输入法未跑。 |
| C68 | TUI鼠标捕获、Shift选择、双击选择、复制 | NOT RUN | 沿用Ghostty鼠标/选择；全组合未重测。 |
| C69 | 拖选到上下12pt边缘，停住/松手/切窗 | NOT RUN | 沿用边缘自动扩选实现；实际拖选/停住/松手序列未重测。 |
| C70 | URL/OSC8/折行链接、⌘点击与右键复制链接 | NOT RUN | OSC8/折行/点击/复制链接全组合未重测。 |
| C71 | 普通文本、多行、大段粘贴、文件/图片粘贴 | NOT RUN | 普通命令粘贴已用；大段与多行bracketed paste未完整测。文件/图片投递按SCOPE删除。 |
| C72 | 恢复输入模式、显式中断并修复 | NOT RUN | 恢复与中断仍为分开路由；不发Ctrl-C的原生序列未重测。 |
| C73 | 默认浅/深、Catppuccin浅/深、系统跟随 | NOT RUN | 默认浅/深本轮截图；Catppuccin与系统跟随/运行中切换全组合未跑。 |
| C74 | 改字体、字号、字重、行距、恢复默认 | NOT RUN | 字体逻辑保留；字号/字重/行距/恢复默认完整实际输入未跑。 |
| C75 | 主窗口非key、设置在前、全屏/退出全屏 | NOT RUN | key/non-key和设置显示已观察，低版本矩形回退；全屏/退出与所有边框组合未跑。 |
| C76 | VoiceOver按顺序遍历、激活、调宽、取消 | NOT RUN | 已补按钮、行、Tab和分隔器AX语义/键盘调宽；没有启用真实VoiceOver完整遍历。 |
| C77 | 键盘全访问、增加对比度、减少动态效果 | NOT RUN | 形状+文字区分状态；系统增加对比度/减少动态效果/键盘全访问未启用。 |
| C78 | 中文/英文全部菜单、tooltip、alert、AX | NOT RUN | 新增固定文案中英均有key；中文设置与确认已观察；英文全部菜单/AX未全遍历。 |
| C79 | 通知未授权/允许/拒绝/系统设置修改返回 | NOT RUN | 设置激活时刷新通知权限已实现；未改变用户系统通知权限，未发送真实通知。 |
| C80 | 更新页Brew/直接下载/无签名配置 | NOT RUN | native subset证据： 当前Debug About显示0.1.5 build1，Brew记录归属不确定及缺签名原因；未改更新渠道。 |
| C81 | 400Agent、多个设备，滚动并搜索 | NOT RUN | bounded metric证据： 400合成Agent元数据/2设备，真实原生GUI输入与滚动往返耗时、CPU/RSS，详见PERFORMANCE.md；不是400实际Agent进程。 |
| C82 | 12Tab/24surface切换，后台持续输出 | NOT RUN | partial native证据： 12Tab/24服务器surface+1Shell，两轮切换，1343次连续隐藏观察无frame/resize变化，身份无变化；后台持续输出全负载未跑。 |
| C83 | ⌘H隐藏/恢复、最小化/恢复、长时间闲置 | NOT RUN | 隐藏不拆attach已修；最小化、隐藏、长时间闲置完整组合未测。 |
| C84 | 连续状态变化和同值快照 | NOT RUN | source/model证据： 相同Session不发布/reindex；Search缓存复用与稳定ID测试通过；高频原生闪烁测量未完成。 |
| C85 | 通用测试插件无/一/多项，动作失败/日志很长 | NOT RUN | 插件界面loading/error/empty/动作保留并锁定上下文；本轮通用插件无/一/多及长日志未运行。 |
| C86 | 文件预览删除后resize、主题切换、旧偏好存在 | REMOVED_BY_SCOPE | 用户明确删除传输与投递；C86–C90按删除范围退出目标。 |
| C87 | 若保留传输：路径不存在/无权限/未选设备 | REMOVED_BY_SCOPE | 用户明确删除传输与投递；C86–C90按删除范围退出目标。 |
| C88 | 若保留传输：换设备时旧慢请求返回 | REMOVED_BY_SCOPE | 用户明确删除传输与投递；C86–C90按删除范围退出目标。 |
| C89 | 若保留传输：冲突取消/替换/保留两者、取消、⌘W | REMOVED_BY_SCOPE | 用户明确删除传输与投递；C86–C90按删除范围退出目标。 |
| C90 | 若保留附件：未知能力、本机/SSH、目标中途改变 | REMOVED_BY_SCOPE | 用户明确删除传输与投递；C86–C90按删除范围退出目标。 |
