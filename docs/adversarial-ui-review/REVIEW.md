# HerdrX UI 与交互对抗式审查

日期：2026-10-11。基线：`8a6126a6a23b68637036f6292d3503994eff994b`（master / 0.1.12）。

结论：原生工作台的方向、主题和主要间距已有基础，接下来最有价值的是减少无效操作、稳定布局、压缩辅助文字，以及让鼠标、键盘与输入法遵循相同的行为。已有截图不能证明当前代码的全部状态都精致。本轮列出的 14 项源码问题与追加的 6 项设计/交互问题，现均已提供修正；**原生视觉验收仍未完成，不据此宣称生产就绪。**

## 方法与证据边界

- 阅读 AGENTS.md、PRODUCT.md、DESIGN.md，以及最近的标签、面板间距、窗口圆角、设置、连接恢复验证记录；审查 App 下全部主要界面的源码和调用路径。
- 按“无数据 / 一项 / 多项 / 长文本 / 窄窗口 / 离线 / 忙碌 / 异步返回 / 鼠标 / 键盘 / 中文输入”挑战各入口，而不只判断静态截图是否好看。
- 打开了仓库里的原生历史截图：[当前基线四分屏](../pane-corners/evidence/grid-sidebar-dark.png)、[标签溢出](../connection-recovery/evidence/tabs-overflow.png)、[含 Agent 的工作台](../accm-fidelity/screenshots/workbench-light.png)、[终端设置](../accm-fidelity/screenshots/settings-terminal.png)、[外观设置](../accm-fidelity/screenshots/settings-appearance.png)。后四者早于当前基线，只用作信息密度和既有设计方向的证据。
- 本次执行环境为 Linux，无 AppKit、SwiftUI、Xcode 或 macOS GUI。没有运行原生应用、操作用户会话或制作替代界面截图。下表的“源码”表示可指出的分支/约束问题，**不表示已经在屏幕上复现**。
- P1：可能中断用户输入、造成错误操作预期或丢失导航上下文；P2：降低清晰度、一致性或操作效率。严重度针对本次 UI 范围。

## 已提供修正的 14 项问题

| ID / 级别 | 对抗场景与证据 | 当前分支的行为 |
| --- | --- | --- |
| U01 / P1 | 右键小面板或离线面板，“Split”仍可选；回调先 `activate`，再校验。放大状态又用已放大的终端 frame 判断是否放得下。[Objects](../../App/Objects.swift)、[Navigation](../../App/Navigation.swift)、[Desk](../../App/Desk.swift)。 | 按右键目标、连接、忙态及未放大的真实布局判断；无效操作禁用。直接传递目标，不为一次失败的分屏改变选中项。成功后恢复布局；等待期间切换焦点时不抢回焦点。尺寸变化刷新可用状态。 |
| U02 / P1 | 重命名的 field-editor 委托直接消费 Return / Escape，缺少 SearchInput 已有的 `hasMarkedText()` 保护。[原始 TabRename](https://github.com/cleanwk/herdrX/blob/8a6126a6a23b68637036f6292d3503994eff994b/App/TabRename.swift)。确认/取消输入法候选存在被当作提交/取消的风险。 | [RenameInput](../../App/RenameInput.swift) 在组合输入期间交还事件给输入法，提交后的普通 Return / Escape 保持原行为。增加生产输入控件的原生委托测试。 |
| U03 / P1 | 筛选某设备后移除该设备，`remove` 没有清除 `deviceFilter`，列表继续过滤一个不存在的 ID；切换器却显示 All Devices。[Desk.remove](../../App/Desk.swift)、[DeviceSwitcher](../../App/DeviceSwitcher.swift)。 | 移除正在筛选的设备时恢复 All Devices，列表与标签保持一致。 |
| U04 / P2 | 剪贴板只要含任意类型就点亮 Paste，执行时却只读字符串；纯图片会形成无反应操作。已结束的 attachment 也可粘贴。[Objects.paneMenu](../../App/Objects.swift)。 | 仅非空文本且 attachment 未结束时可粘贴；执行时再次检查。保留选区复制。 |
| U05 / P2 | 面板标题与终端正文共用完整菜单，标题上也出现 Copy / Paste，甚至可能带上正文之前悬停的链接。[Terminal.Canvas.menu](../../App/Terminal.swift)。 | 明确区分标题菜单与正文菜单；标题只包含面板操作，链接操作仅留在正文。 |
| U06 / P2 | 单个 Tab 仍有两个永远禁用的移动项；单个 Pane 可放大/移到新 Tab；已连接设备仍显示 Retry；面板关闭按钮不反映离线/忙态。[Tabs](../../App/Tabs.swift)、[Workbench](../../App/Workbench.swift)、[Terminal](../../App/Terminal.swift)。 | 单项时省去排序；只有多面板或正在放大时提供放大/还原，只有多面板时提供移至新标签页；连接正常时不提供 Retry。面板关闭按钮按其目标禁用。 |
| U07 / P2 | Space、Tab、Agent 的关闭项紧接在改名/复制/排序后，没有操作分组。[Workbench](../../App/Workbench.swift)、[Tabs](../../App/Tabs.swift)。 | 用原生分隔线区分整理操作与终止操作；保留现有明确目标和服务端进程影响的确认。 |
| U08 / P2 | Tab 宽度使用当前字体测量，选中改为 semibold 后宽度随之变化，相邻标签/插入点可移动。[Tabs.Strip.syncButtons](../../App/Tabs.swift)。 | 所有状态按 semibold 预留同一宽度，实际字重仍区分选中状态。保留 28/22/3pt 几何及水平滚动。 |
| U09 / P2 | Agent 状态 `.fixedSize(horizontal: true)` 无上限；200pt 侧栏下，英文 Completed, unread 或服务端长状态挤占工具/空间上下文。[Workbench.agentRow](../../App/Workbench.swift)。 | 可视未读状态缩为 Unread / 未读，状态列固定 64pt 并截断超长值；完整状态保留在 help 和无障碍值中。状态与上下文各自有稳定区域。需要原生英文复验。 |
| U10 / P2 | 文档规定失焦窗口收敛面板焦点色，绘制却只判断 `focused == key`，也没有监听 resign-key。[Terminal.Canvas](../../App/Terminal.swift)。 | 同时观察窗口获得/失去键盘焦点；窗口不活跃时使用中性边框和标题。 |
| U11 / P2 | “Add Device…”通过 `SettingsLink` 加 `TapGesture` 才设置目标页，鼠标、键盘和无障碍激活不是同一个动作。[DeviceSwitcher](../../App/DeviceSwitcher.swift)。复查还发现设置可能保留 Plugins 子页或旧的编辑表单。 | 一个原生按钮动作依次重置为 Devices 新建表单、设定 Connections、关闭弹层、打开设置。只有明确 Add Device 时重建表单，普通打开设置保留原状态。长设备名中间截断，并补全悬停名称。 |
| U12 / P2 | “New Space with Name and Directory…”、设置导入按钮过长；Rename Sheet 重复解释普通文本框支持的字符；英文 Color mode 被限制在 48pt 标签列；中文含“重命名 面板”和 `copy_on_select` 实现术语；字体导入失败拼完整路径且不本地化。 | 新建菜单缩为 New Space…；设置发现/导入按钮缩短并可垂直回退；移除重命名冗余说明；Mode / System / Light 使用短标签。清理中文空格和实现说明；导入错误双语化，以文件名定位。 |
| U13 / P2 | 旧设置允许 Semibold / Bold，当前字体预览仍使用它们，分段控件却只列 Light / Regular / Medium，出现实际字重与选中状态不对应。[Preferences.TerminalSettings](../../App/Preferences.swift)。 | 若当前保存的是旧字重，临时显示对应选中段；不覆盖用户偏好。选择当前常用字重后回到三段。 |
| U14 / P2 | Connection Details 展示 SSH target，但 Copy Details 丢掉 target 和设备名，多设备同路径时复制结果难以定位。[ConnectionRecovery](../../App/ConnectionRecovery.swift)。 | 复制内容包含设备名、主机、socket 和原始错误。 |

## 每个右键菜单为什么保留这些项

“入口在别处也存在”不等于应该删掉：右键操作需要保持对点击对象的明确指向；Tab 的移动项也为不能拖动的用户保留可达路径。

| 对象 | 保留 | 条件显示 / 可用性 | 分组与取舍 |
| --- | --- | --- | --- |
| 设备组 | New Space…；恢复连接相关操作 | Start 仅支持且已停止的本机；Retry 仅未连接，连接过程中禁用 | 正常连接不提供“重试”。无需把完整连接设置复制到菜单。 |
| Space | Rename…、Copy Directory、Close Space… | 多空间才显示上下移动；首尾边界禁用；写入受连接/忙态约束 | 改名/路径、排序、关闭三组。复制路径对远端也有用，不替换为只适用于本机的 Finder 操作。 |
| Tab | Rename Tab…、Close Tab… | 多 Tab 才显示左右移动，边界禁用 | 改名、排序、关闭分组；保留双击改名和拖动。单 Tab 菜单只需两项。 |
| Pane 标题 | Rename Pane…、Split Right / Down、Close Pane… | 分屏按空间/连接禁用；多面板才放大或移至新 Tab；放大后提供还原 | 移除文本和链接操作；关闭独立分组。标题属于对象，不是正文选区。 |
| 终端正文 | Copy、Paste，以及面板操作 | Copy 要有选区；Paste 要有可用文本；仅链接悬停时提供 Open / Copy Link | 文本、面板、关闭三组。无需增加 Copy All、Clear 或 Select All 等未经需求验证的新项。 |
| Agent | Rename Pane…、Copy Directory、Close Pane… | 目录不可用时禁用复制；写入受连接/忙态约束 | Agent 是现有 Pane 的入口，保留精简菜单；不复制所有布局操作到侧栏。关闭单独分组。 |

## 排版与设计判断

- **保留现有 pane 几何。** 8pt 外围/内部分隔、28pt 标签栏、22pt 标签、1.5pt Retina 边框和窗口相邻圆角已有较新原生证据。本轮没有凭旧截图重新改这些值；已有几何回归继续执行。
- **稳定优于装饰。** 选中 Tab 不应使其邻居移动；Agent 状态不应因文字增长挤掉所有上下文；失焦窗口不应继续强调正在接受输入。这比继续调整色相或添加阴影更直接影响使用感受。
- **图标保留原始资源。** Agent 使用带来源的品牌向量，普通命令使用 SF Symbols。没有更换品牌图、添加栅格素材或任意重绘几何。12pt 多品牌的光学大小仍需逐个实机对比。
- **短文案负责行动，完整信息负责辨识。** 菜单写 New Space…，表单再呈现设备/名称/目录；行内用 Unread，help/无障碍保留完整状态。不能靠把全部文字截断来假装长文本已经解决。

## 追加的 6 项：已完成实现，运行时验收仍单独记录

| ID / 级别 | 已实现的修正 | 验证与验收方式 |
| --- | --- | --- |
| R01 / P2 | Tab 名称与面板数用独立文本槽绘制，计数用 10pt 等宽数字，始终预留尾部宽度；长标题只截断标题。保留原生按钮、焦点环、AX 角色及拖动/右键行为。 | 原生 Tabs harness 检查 200pt 长标签、数字名称、1/2/12 个 pane、计数不重叠、切换不移位，并输出离屏原生控件 PNG。仍需实际应用浅深色/键盘视觉复验。 |
| R02 / P2 | 只缩短可识别的 shell 主机+cwd 标题及纯 cwd，保留用户命名和任意任务 OSC 标题；完整身份保留 tooltip/AX/search。单设备省去重复设备上下文，可用标题宽度小于 260pt 时优先主标题。 | Core 回归涵盖自定义名称、任务标题、匹配/不匹配路径、中文/空格、根目录。多设备同名目录、四分屏仍需原生确认。 |
| R03 / P2 | 本机发现与远端导入共用请求互斥；设置内展示加载、成功数量、无新增和错误，支持取消慢请求，结束后可重试。先完成解析，再检查取消状态后统一导入；重复设备只按实际新增计数。退出应用会取消发现进程。 | 源码检查 busy 在创建 Task 前设置、defer 复位；错误不再只送到工作台 alert。Core 测试启动独立 helper，确认执行中取消会终止进程并返回 CancellationError。慢 SSH、失败与连续点击需隔离服务复验。 |
| R04 / P2 | Space、Tab、Pane 统一使用 RenameSheet 和原生 RenameInput，保留编辑值、就地错误、重试、Enter/Escape/IME 保护。请求捕获 endpoint、对象及父级身份；串行调用原有三个 rename RPC；标签只随服务端快照改变。 | 新增 Core 目标/父级校验与 RPC 契约测试；保留异步队列失败恢复测试；native input harness 覆盖组合/普通输入路由。目标移走、断线、切换设备的运行时矩阵保留。 |
| R05 / P2 | Connections 的 Tailcat Edit 切到对应设备表单；目标 ID 被一次性消费，进入编辑清除旧错误、不暴露 token。设备移除后不允许继续保存。长名称中间截断，操作按钮固定尺寸，连接忙碌时 Retry 禁用。 | 源码检查正确设备路由与保存前存在性验证。需 macOS 键盘/VoiceOver 入口、长名称及真实 Tailcat 复验。 |
| R06 / P2 | Workspace 的焦点、尺寸、数字 Tab 各成子菜单；终端修复归入 Terminal。快捷键保持原值，数字菜单双语化。关闭确认按单/多 pane 表述，按钮明确为 Close Pane/Tab/Space，移除无对应入口的 attachment 技术说明。 | Core 快捷键回归保持；源码确认菜单快捷键未改。子菜单原生键盘分发、关闭与取消需要运行时复验。 |

## 交付与验收门槛

修改位于 `codex/adversarial-ui-review`。这是可审阅的 UI 修正，复用已有 Herdr API，不引入新的会话协议或服务端能力。编译、单元/控件测试、运行时交互、视觉接受分别记录，不能互相替代。

详细命令、CI 入口与 macOS 验收矩阵见 [VALIDATION.md](VALIDATION.md)。尤其需要补齐：英文 200pt 侧栏、系统中文输入法、焦点恢复、在非当前面板上右键分屏，以及低速 RPC 下的目标稳定性。未合并或发布应用。
