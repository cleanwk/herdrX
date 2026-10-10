# 性能与表面生命周期实测

2026-10-10，同一 Apple Silicon Mac、Xcode 27、Debug 构建。基线为 3a006f4（应用代码与 v0.1.5 相同），改后为本分支工作树。两者原生窗口均为 1200×760、默认浅色、260pt 侧栏、SF Mono 13pt。设备存储隔离在 build/ux-fixture/perf-state。

## 400 行原生交互

`Tests/fixtures/ux_metadata_server.py` 提供两个只读 session.snapshot/events.subscribe 服务，每台 200 行 Agent 元数据，相同 ID 故意跨设备重复，包含 blocked/working/done/idle/unknown。数据用真实快照结构，但状态为合成，**没有启动 400 个 Agent 或 PTY**。

两版各在真实原生搜索框中依次输入 dlxf、001、denglu、never-match、020，循环四次。每次计时从 Cmd+A 开始，经输入到辅助功能树返回。滚动在搜索关闭后，从侧栏顶部向下滚一页，重复十次；每次从滚动操作到 AX 返回。期间未见明显卡住或输入丢失。

| 操作往返耗时 | 基线 p50 / p95 | 改后 p50 / p95 | 样本 |
| --- | --- | --- | --- |
| 搜索输入 → AX 可读 | 817 / 875 ms | 810.5 / 875 ms | 各 20 |
| 侧栏滚一页 → AX 可读 | 912 / 1025 ms | 825 / 973 ms | 各 10 |

p95 使用 nearest-rank。改后首次搜索样本为 1462ms，基线首次为 503ms；未剔除。原始记录在 evidence/perf-{before,after}-{search,scroll}.json。

**这不是帧耗时、首字符绘制延迟或吞吐指标**：自动化 IPC、键盘输入及 AX 稳定等待占据大部分时间。小样本且没有随机化运行顺序，不能据此宣称 10% 性能提升或零输入延迟。基线关闭搜索后遇到一次自动化 noWindowsAvailable，重新读取窗口后恢复；未计入十次成功滚动。

## CPU / RSS

`ux_sample_process.py` 对应用 PID 每秒采样一次 ps，分别 60 秒。记录窗口包含搜索与空闲时间；滚动在后续单独执行，因此这些 CPU 数字不是滚动负载测量。两者采样时没有并行编译。时间戳与原始值保存在 evidence/perf-{before,after}-process.json。

| 进程指标 | 基线 | 改后 |
| --- | --- | --- |
| CPU p50 / p95 | 1.15% / 35.6% | 1.1% / 43.8% |
| RSS p50 / p95 | 179.5 / 186.5 MiB | 166.9 / 184.9 MiB |
| RSS 最大 | 198.9 MiB | 185.5 MiB |

采样阶段和系统调度未严格对齐，CPU 高分位改后更高。保留原始差异，不据此认定CPU已优化或发生回退。若要比较实际渲染性能，需要 signpost/Instruments 或相同脚本与完全对齐的负载区间。

## 12 Tab / 24 surface

另用真实 `herdrx-ux-20261010-a` 服务器，12 Tab 各 2 Pane，加一个客户端 Shell。原生 Cmd1–9 + next 到12，重复两轮，最后回到1。Debug诊断记录86次布局、25个surface、1343次连续隐藏观察：无surface身份变化，无隐藏frame或resize计数变化。每个服务器PTY计2次resize（首次布局），客户端Shell计3次。`evidence/surface-reuse.json`为汇总，原始本地日志在build/ux-fixture/final-surfaces.jsonl，键盘动作在evidence/24-surfaces-tab-cycles.txt。

本阶段终端只包含隔离提示文本；没有把24个后台持续输出程序的吞吐、可见未聚焦输出或长时间闲置当成通过。基线没有同粒度resize计数，故此项是改后生命周期验证，不是前后CPU基准。
