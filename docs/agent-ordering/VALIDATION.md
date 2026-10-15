# Agent sidebar ordering

The sidebar includes local unread state in its presentation order: blocked, working, unread completion, read completion, idle, unknown. Existing order within each group is preserved. Server Agent state and search ranking are unchanged. The computed sidebar order observes attention state, including when leaving a pane marks its completion read.

`Core/Tests/HerdCoreTests/AttentionTests.swift` covers unread promotion, device isolation, marking read and stable ordering of completed results.

Validation in the Linux editing environment: `git diff --check` passed. Swift is unavailable, so Core tests and the macOS build were not run. Native sidebar rendering and live status/read transitions still require macOS verification; no visual acceptance is claimed.
