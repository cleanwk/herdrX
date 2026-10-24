# HerdrX P0 修复落地说明

分支：`codex/fix-p0-input-tab-close`
PR：https://github.com/cleanwk/herdrX/pull/35
CI：`Build and test`（含 `scripts/package.sh` 预览全包）已触发  
对照：`/workspace/herdrm`、审计报告 `/workspace/herdrx-audit-report.md`  
日期：2026-10-24（Asia/Shanghai）

## 改了哪些文件

| 文件 | 用途 |
| --- | --- |
| `App/Objects.swift` | `pane.close` 先 `detachClosedPane`，失败回滚 |
| `App/Desk.swift` | `detachedPanes`、乐观 `Layout.removing`、`layoutRects`/`ensureAttachments` 跳过已拆 pane、reconcile 清理 |
| `App/Terminal.swift` | `intentionalClose`：stop 时跳过 observe/`onExit`，并清空 `process.output` |
| `App/Tabs.swift` | 本地 `NSEvent` monitor 吃满 left-drag/up；Scroll/Clip `mouseDownCanMoveWindow=false`；拖拽中不因 poll 换序 `stopDrag`；减少无谓 `needsDisplay` |
| `App/SelectionTerminalView.swift` | composing 时 `selectedRange` 委托 Ghostty；异步 `insertText` 先 unmark 并检查 binding；`unmarkText` 收干净 |
| `Tests/SelectionTests.swift` | 组合中允许 preedit caret；unmark/异步提交后仍钉死 `{0,0}` |

## 每个 P0

### P0-1 关 pane 卡顿 + 闪 `terminal … not found`
- 确认后立刻本地 stop 表面 + 乐观布局扩邻格，再 RPC + scoped refresh。
- 故意关闭不启动 observation、不进 `ended` overlay；尽量避免 exit banner 写屏。

### P0-2 Tab 拖拽只能挪一点点
- `mouseDown` 安装 local monitor，消费 `.leftMouseDragged` / `.leftMouseUp`，避免 `isMovableByWindowBackground` 抢事件。
- 不用 `trackEvents`（会卡住 `TabScrollTests` 的离散 `sendEvent`）。
- 拖拽进行中，仅源 tab 消失或变只读才 `stopDrag`。

### P0-3 豆包 IME composing 卡住
- 有 marked text 时 `selectedRange()` → `super`（Ghostty preedit caret）；无组合时仍 `{0,0}`（保 0.1.19 语音提交）。
- 异步 `insertText`：先 `unmarkText`，binding 失败再 `super.insertText`。
- **必须在 Kai 本机用豆包短按/长按/语音验收**（Linux box 无法跑 AppKit/IME）。

## P1（顺手）
- Tab `updateNSView` 仅在 tint 变化时 `needsDisplay`，减轻 Desk 刷新风暴下的 Tab 重绘。

## 本环境测了什么
- `python3 -m unittest discover -s scripts -p 'test_*.py'` → 14 OK
- **未跑**：`swift` / `xcodebuild` / `scripts/test-tabs.sh` / `test-selection.sh` / `test-panes.sh` / `test-inputs.sh` / `package.sh`（Linux box 无 macOS 工具链）
- CI（PR / push master）会跑完整矩阵并 `scripts/package.sh` 打预览包

## Kai 本机验收步骤
1. **关 pane**：多格 Tab 关中间/边格 → 邻格应立刻扩满；终端不应闪 `terminal … not found` / Reconnect；失败时应回滚。
2. **Tab 拖拽**：开 `isMovableByWindowBackground` 的工作台，鼠标与触控板把宽 Tab 拖过多个邻居落位；拖中 Escape / 失焦应取消。
3. **豆包 IME**：短按松手、长按松手、语音听写、中英切换、候选确认；对照 Ghostty.app。组合结束后不应残留下划线 composing。
4. 回归：普通选区拖拽、Ctrl-C interrupt、语音异步提交（0.1.19 场景）。

## 已知限制
- IME / 真机拖拽 / 关 pane 体感延迟只能在 Mac 上最终确认。
- Desk `@Published` 拆分、双 `workspace.get` 等更大 P1 未做，避免大范围 UI 重设计。
