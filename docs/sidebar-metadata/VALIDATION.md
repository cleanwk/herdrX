# Sidebar Git metadata — 2026-10-13

## Problem and contract

The installed app's native accessibility help showed `/root` followed by `bash: line 1: git: command not found` for the reported remote rows. Herdr connectivity was healthy. The optional Git probe was being presented as “Directory unavailable”, incorrectly implying the directory itself could not be used.

Branch lookup now keeps a neutral folder/Directory row during loading or failure, or retains the last branch name without an inline stale warning. Help retains the raw diagnostic and a localized explanation that Git branch information could not be refreshed. Device connection status, Herdr snapshots, refresh timing, target guards, navigation and terminal surfaces are unchanged. Server-provided branch tokens still take priority over the helper probe.

## Initial checks on the 0.1.12 base

- `xcodegen generate` and the arm64 Debug Xcode build passed. The build reported only the existing AppIntents metadata extraction warning (no framework dependency). Log: `build/sidebar-metadata/build.log`.
- `swift test --package-path Core -c release`: 28 tests passed, zero failures. Log: `build/sidebar-metadata/core-tests.log`.
- Both English and Simplified Chinese string files passed `plutil -lint`; design JSON parsed; `git diff --check` passed.
- Read the installed Herdr protocol 22 schema and existing client calls. Validation used existing `workspace.create`, `workspace.report_metadata` and `session.snapshot` contracts; no new protocol or remote dependency was introduced.
- Built-app validation used `build/sidebar-metadata/HerdrX Sidebar Check.app`, bundle ID `io.github.cleanwk.herdrx.sidebar-metadata`, `HERDRX_STATE_DIR=build/sidebar-metadata/state` and only the disposable named session `herdrx-sidebar-metadata-20261013`. Fixture workspaces and helper files are under `build/sidebar-metadata/`. The explicitly synthetic server token was `synthetic/server-branch`; no Agent metadata was fabricated.
- With an isolated PATH containing no Git, native accessibility showed `Missing Git · 缺少 Git、目录` and `Branch · 分支、目录`, with the localized refresh explanation and `git: command not found` in help. The connected-device state and mounted terminal remained available. The synthetic server branch was still displayed.
- A native screenshot confirmed ordinary folder icons, two-line row geometry and no warning triangles in Chinese/light appearance at 1200×760pt, with the 260pt sidebar. No new layout, typography, color or raster assets were introduced.
- Restoring Git to the fixture PATH recovered automatically on the existing refresh interval: the non-repository stayed Directory, the repository showed `fixture/sidebar`, and failure diagnostics disappeared from help. No reconnect or app restart was needed.
- Removing the fixture Git helper again preserved `fixture/sidebar` while help regained the refresh diagnostic. Switching to that Space still selected its mounted terminal. Native accessibility confirmed no inline stale suffix or warning label.
- Quit the isolated GUI and stopped only `herdrx-sidebar-metadata-20261013` after the checks. No production session was stopped.

Finish verdict: the reported misleading warning is resolved in the built app. The existing native row hierarchy is preserved; optional metadata failure no longer competes with connection health.

## Limits

The production app was inspected read-only. Its remote servers were not changed or given Git. Initial checks did not replace the installed app or publish a release. Live remote recovery, VoiceOver operation, dark appearance and English running-app layout were not exercised for this presentation-only change. Existing asynchronous request targeting was not modified or independently revalidated.

## 0.1.17 release preparation

Rebased the fix onto the published 0.1.16 mainline (`edef390`), preserving its terminal, integration and signed-delta changes. Updated VERSION, project.yml, README and release notes together.

- Regenerated the Xcode project and rebuilt the arm64 Debug app successfully on the updated base.
- All 63 Core release tests and 14 Python release tests passed. Local logs: `build/sidebar-metadata/release/`.
- Repeated native verification in the disposable session `herdrx-sidebar-release-20261013`, with the isolated app/state directory. A deliberately malformed fixture Git config produced the ordinary folder/Directory row, with `fatal: bad config line 1 in file .git/config` only in help. A normal repository showed `fixture/sidebar`, and synthetic server metadata showed `synthetic/server-branch`. Native screenshot and accessibility inspection confirmed the current rendering. Quit the isolated app and stopped only that named test session.
- Complete CI and public artifact verification are release gates; local installation is left to the user.
