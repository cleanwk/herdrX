# 对抗式 UI 审查验证记录

2026-10-11；基线 `8a6126a6a23b68637036f6292d3503994eff994b`。审查与实现说明：[REVIEW.md](REVIEW.md)。

## 本地已执行

- `git diff --check`：通过。
- `python3 -m unittest discover -s scripts -p 'test_*.py'`：6 项通过。这是既有打包/更新契约回归，**不是 UI 验收**。
- 英文/简体中文 `.strings`：键集合相等、无重复键、格式占位符对应；当前新增及修改文本双语齐全。
- `bash -n scripts/test-inputs.sh`：通过。
- 静态回调复查：正文/标题两类菜单均绑定原 PaneKey；分屏先检查点击目标，执行中保留 device、tab、endpoint；返回时检查原焦点及目标；Popover 的添加设备入口使用单一 Button action；设备移除时同步筛选值。
- 阅读历史原生截图，没有为本次代码生成或采集新的运行截图。

## 原生自动检查

当前 Linux 环境不能执行下面的 macOS 命令；它们通过本分支的 `Build and test` CI 运行。[PR #18 当前 checks](https://github.com/cleanwk/herdrX/pull/18/checks) 对应最终提交，基线的成功 CI 不接受本分支。

已实际确认的检查点：

- `dd50f670`：[首批修正 CI](https://github.com/cleanwk/herdrX/actions/runs/38124371870) 全部通过。
- `e46fa63f`：[全部 20 项主要实现 CI](https://github.com/cleanwk/herdrX/actions/runs/38125193913) 全部通过：32 项 Core 测试、6 项 Python 契约测试、universal Release 构建、PTY、Tabs、Inputs、Pane geometry、预览打包。取消正在运行的 helper、重命名父级校验和 shell 标题回归均通过。
- 收尾补充了 Add Device 从 Plugins/旧编辑表单重置的路由、Tailcat 错误排版，以及浅/深色原生控件截图背景；最终状态以以上 PR 当前 checks 为准，不把已通过的旧提交代替当前 head。

构建日志仅有工具链的 AppIntents metadata 提示（项目未依赖该框架），没有观察到新增源码编译警告。日志和 ZIP 下载保留在本地忽略目录 `build/adversarial-ui-review/`，没有发布 Release。

| 入口 | 覆盖范围 |
| --- | --- |
| `scripts/build.sh` | Core 测试（含新增 shell 标题投影、重命名父级/目标和 RPC 契约、运行中 helper 取消）、XcodeGen、arm64/x86_64 Release 编译和签名/架构校验。 |
| `scripts/test-tabs.sh` | 直接编译生产 Tabs.swift；原有滚动、边界、resize、reveal；新增切换所有标签时 frame 不变、点击非选中标签的菜单目标、菜单分隔/单项/离线状态、长标题与独立计数不重叠。输出 `tab-chrome-light.png` / `tab-chrome-dark.png`：生产控件配测试用系统语义色和不透明原生窗口背景的离屏证据，不是整窗应用或全部主题验收。 |
| `scripts/test-panes.sh` | 原有边框、1×/2×、圆角、网格和 gutter 回归；新增窄 pane 与大画布的分屏容量差异、水平/垂直阈值和零尺寸。它检查几何，不模拟真实 Herdr RPC。 |
| `scripts/test-inputs.sh` | 直接编译 RenameInput.swift / SearchInput.swift；组合输入时 Return/Escape/箭头不被拦截、普通输入时动作仍执行、提交文本同步。marked text 由 NSTextView 测试替身提供，不等同于真实输入法候选窗验收。 |
| `scripts/test-pty.sh` | 现有终端进程和 attach 代次回归。 |
| `scripts/package.sh` | 既有 universal 预览包检查，不发布 Release。 |

## macOS 运行时验收矩阵（本轮 NOT RUN）

只使用明确命名的可丢弃 Herdr 会话和独立 `HERDRX_STATE_DIR`，不能把用户真实任务作为关闭/分屏 fixture。Agent 状态注入需标注 synthetic。测试完只停止该 fixture。

| 场景 | 通过标准 |
| --- | --- |
| 最小/默认/宽窗口：980×620、1200×760、1440×900；侧栏 200/260/480pt | 无控制相互遮挡；标签中心、pane 边框和 gutters 保持原契约。超长 Space/Agent/device 名留有可用操作区。 |
| 中英文、浅深色、Agent working/blocked/unread/自定义长状态 | 状态列不推走工具/空间；Unread 完整可见，截断状态有完整 help 与可访问值。文字颜色清晰。 |
| 20 个标签、长短标题、持续切换与拖动 | 选择时邻居位置不动；右键仍指向点击对象；边缘滚动、插入线、恢复选中可见正常。 |
| 非当前 Pane 的标题/正文右键 | 标题无文本/链接项；正文仅在对应条件下提供剪贴板/链接操作。取消菜单不改变焦点。 |
| 窄 Pane 放大后尝试分屏；离线；已有请求未完成 | 不按放大后的大 frame 放行小 pane 的无效分屏；不可用项禁用；直接关闭按钮同样禁用。 |
| 延迟 pane.get / pane.split 后切换焦点、Tab 或设备 | 只对捕获的目标操作；不把新 pane 焦点抢到用户已离开的上下文。目标移走/消失有明确反馈。 |
| 系统拼音输入法重命名 | 第一次 Return 选词，后续 Return 才提交；组合输入中 Escape 先取消候选，普通 Escape 关闭 sheet。双击、菜单、快捷键三个入口一致。 |
| 键盘/VoiceOver 打开 Add Device… | 包括之前位于 Plugins 子页或旧连接编辑表单，均落在 Connections → Devices 的新建表单，popover 关闭；焦点可继续进入表单。普通打开设置保留现有状态。 |
| 删除正在筛选的设备 | 筛选回到 All Devices，其他设备与空态一致，没有“全部设备”标题却空列表。 |
| 工作台 → Settings / 另一应用 → 工作台 | 非活跃窗口不保留强面板焦点色，返回正确终端；Cmd-W 在 sheet/settings/workbench 各自只执行预期的关闭。后者是复验风险项，未据源码确认有故障。 |
| Settings 字号 9/13.5/22pt、旧 Bold/Semibold、英文 | 控件与预览一致；当前保存的旧字重有选中项；操作按钮不横向溢出；导入错误可读且可滚动。 |
| 1×/2×、全屏/退出全屏、Reduce Motion、VoiceOver | 保留历史 pane 几何契约；新焦点表现不引入闪动；图标光学大小/线条/可访问名称需人工确认。 |

追加复验：在 Settings 内慢速发现/导入时连续点击，确认只启动一次、结果就地显示且可重试；取消慢导入后不添加设备，可再次发起；从 Connections 用键盘编辑 Tailcat 的指定设备，再移除目标，确认不会保存到失效对象；Space/Pane 改名失败后原输入保留，目标移到另一 Tab/Space 后提交被拒绝；数字 Tab 子菜单和分组后的导航快捷键保持可用。

Live SSH/Tailcat、长时间运行、macOS 14–26、Intel 实机、通知权限/投递、签名更新端到端均未在此环境复验。没有合并、安装替换、tag、Release 或 Homebrew 发布。
