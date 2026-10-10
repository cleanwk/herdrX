# 本轮实现与验收

本轮把 HerdrX 收敛为 Space / Tab / Pane、真实终端、连接、Agent状态与搜索。用户最新补充“全删除了吧传输投递都不需要”覆盖早先可选能力，见 [SCOPE](SCOPE.md)。原始审计保留在 [SPEC](SPEC.md)。

## 基线与源码

- 实现从 `3a006f4` 开始，审计基线为 `7778a02` / v0.1.5，两者应用源码相同，只有 README 差异。工作分支 `codex/core-ux-subtraction`。
- 原生测试应用：Debug `0.1.5` build `1`，独立开发 bundle，未覆盖 `/Applications/HerdrX.app`。
- 当前未发布、未 push、未升级 Brew。现有 CI/release/tap 渠道未变动；本地 build 成功不等于 GitHub 发布成功。

## 删除与消费者核对

删除 AgentLaunch、AgentCommand/命令覆盖、⌘N；删除 Files/文件树/只读预览/宽窄辅助区、⌘⇧E/F；删除双端传输、附件能力设置、文件/图片投递和粘贴拦截，以及独占的 Core Files、Arguments 与测试。通用命令执行小工具因 Git/连接发现仍有真实消费者而保留为 CommandProcess。普通终端文本 copy/paste、Agent 自动识别快照、状态导航和 Herdr 插件接口保留。

旧偏好不再读取，没有清理用户文件、远端数据或 Keychain。历史 parity 文档已标明范围被覆盖，README/PRODUCT/Architecture 与当前目标同步。

## 行为变更

T01–T05 已落实实现，T06 完成定向自动测试与部分原生验收，剩余项逐项列出。T07 / UX28 按用户决定删除。

- UX01/05/06/07/13：统一标题投影、创建目标、设备状态与筛选揭示；Pane/Tab人工命名优先，工具命令不当任务标题。高级创建不回退到第一个在线设备。
- UX08/10/11/14/15/16/26：Tab选中自动可见，双击原生重命名、边缘拖动横滚、相邻关闭回落、稳定搜索ID、精确快捷键、按对象/意图忙态及明确关闭语义。Canvas仅显式导航恢复焦点；异步创建与插件动作捕获原始设备/工作区。
- UX02/03/04/09/12/17/19/20：28pt栏和40pt头尾保留，主导航中性，Agent两行任务/上下文+状态，分支固定次级行，Pane主名/弱上下文和关闭槽，最小网格、外窗角适配。
- UX18/21–25/27：按钮/Tab/分隔器AX名称与调宽动作；设置合并为外观、终端、连接、关于与更新，连接草稿完整重置，插件loading/error/empty，退出状态保留，通知权限返回刷新，Brew归属不确定与缺签名原因可见。

## 验证边界

[完整 C01–C90 表](ACCEPTANCE.md) 区分原生、纯模型、源码和 NOT RUN；完整场景缺少证据时即使部分模型已通过，也保留 NOT RUN。没有把所有90条标为完成。

核心19项、真实PTY 20轮代次和idle/running/unknown判定已通过。Debug与仓库scripts/build.sh的universal Release构建通过（arm64+x86_64，ad-hoc codesign严格校验通过），发布契约4项通过。独立视觉审阅在下文记录。原始日志位于 evidence/。

已实际操作：两设备独立fixture；B空组创建的正确目标与仅一套空间/标签/面板；服务器Pane关闭取消（25个仍在）；独立Shell sleep忙确认与取消；搜索键盘Down/无结果/关闭；Tab9自动可见；12Tab/24surface两轮复用。Agent状态由报告API合成，未宣称真实CLI检测完成。

截图位于 screenshots/：默认浅色980×620，侧栏200/260；默认深色1440×900，侧栏480；SF Mono13；包括搜索空态、About和两个关闭确认。只展示隔离fixture。`sidebar-adjustment-with-fixed-cli-override.png`实际仍260，不冒充200截图。

[同口径性能记录](PERFORMANCE.md) 包含原生400行搜索/滚动操作往返、60秒CPU/RSS及真实surface/resize计数。自动化往返不等于渲染帧延迟，CPU采样没有支持性能提升结论。

尚未验证：真实IME/VoiceOver/通知点击、SSH/Tailcat远端、macOS14/15与Intel实机、全部主题/字体/全屏组合、慢RPC故障竞态、后台持续输出和长时间闲置。代码审查不能代替这些实机结果。V类风险没有全部在基线复现：本轮明确保留此前审计风险与本次实测故障的区别。

## 收尾复核与交付状态

Impeccable 独立 finish reviewer 最初 disposition 为 fix：F1 为状态词与 Pane 主标题对比度，F2 为旧 DESIGN 文档。已统一使用原生 primary/labelColor 文字，保留状态点与焦点边框；重捕浅色200/260与深色480截图。独立 documenter 完成 DESIGN.md 与 .impeccable/design.json，YAML/JSON及引用校验通过。reviewer 的限定 verdict 为 **ship，F1/F2 均 resolved**；这不扩大为 C01–C90 或完整主题矩阵通过。见 [FINISH-REVIEW](FINISH-REVIEW.md)。

最后移除 Tailcat 说明里已过时的文件能力句子，并完成 universal Release 增量构建与严格 codesign 校验。0.1.5/build1 为本地验证版本标识，没有修改 VERSION，也没有发布同版本覆盖包。19项核心测试0失败0跳过，4项发布契约测试通过，PTY代次和活动判定通过。构建摘要见 evidence/build-summary.txt。

隔离 Debug 应用、两个 herdrx-ux 命名服务器与两个元数据服务均已停止；原用户服务及已安装应用未停止。诊断文件留在忽略的 build/ux-fixture。没有新增发布 tag、GitHub Release、tap 提交或 Brew 安装变更。
