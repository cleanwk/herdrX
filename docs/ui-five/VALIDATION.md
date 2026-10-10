# Five-point native UI refinement — 2026-10-10

Implemented as presentation and interaction changes around existing Herdr RPCs. Herdr remains authoritative for names, sessions, pane lifecycle and layouts. No protocol additions or client-owned session/name store.

## Changes

- One 28pt integrated bar, 22pt pills centered with 3pt clearance, 8pt leading inset, 4pt gaps and measured title +18pt width. Active 11% accent wash/1pt border; inactive 6% neutral wash and secondary text.
- Close keeps a 22×22pt native button, 50% opacity on the focused pane, full opacity over the pane/button or with VoiceOver, interruptible 150ms ease-out and Reduce Motion support. Hidden controls have neither a hit target nor an accessibility element. An opaque backing masks the title outline during fades. Header right-click uses the clicked pane's existing menu; ⌘⇧W still routes to existing pane.close confirmation.
- Shared split boundaries are backing-pixel aligned, square and 1pt. Focused borders draw last. Only actual bottom outer corners use an 11pt continuous curve; the terminal uses the matching concentric 7.5pt mask. Sidebar-visible left and full-screen corners remain square.
- Original color resources for Claude, Codex, Gemini, DeepSeek, Kimi and Antigravity; upstream monochrome for Cursor, Grok, Copilot, OpenCode and Pi. Original/template choice occurs explicitly in the shared sidebar/search renderer. Missing resources fall back to a terminal symbol. Kimi retains its white/blue paths on black backing. The pinned upstream does not provide color versions of every brand; colors were not invented.
- Double-click/context menu and Terminal → Rename Tab… (⌘⌥R) use a 400pt sheet. Name is focused/selected once, blank/unchanged names cannot submit, Enter saves and Esc cancels. Captured device/endpoint/workspace/Tab identity is validated before the queued existing tab.rename RPC. A server snapshot alone updates the label. Failure retains input, old label and an inline retryable error.

## Verification

- Final Debug Xcode build succeeded. Local full log: build/ui-special-build.log. Unused generated asset symbols are disabled because color/monochrome names otherwise collide; assets are resolved dynamically. Only the existing AppIntents metadata warning remains.
- 22 Core release tests passed, including a suspended failing operation followed by a successful rename: no overlap, no stale-name mutation and no poisoned queue. Unicode, punctuation, blank/unchanged names and shortcut modifier matching are covered in TabRenameTests. Evidence: evidence/core-tests.txt.
- Native AppKit harness compiles the actual Tabs.swift and verifies measured frames, second-tab double-click target and right-click menu contents. Evidence: evidence/tab-harness.txt. Live computer-use could not target Tab radio buttons (cannotClickOffscreenElement), so those two mouse triggers are harness-verified rather than claimed as live clicks.
- Live isolated app: menu and ⌘⌥R open the sheet with text selected; unchanged/whitespace submissions disabled; Esc cancels. Paste of “中文 名称 / #42” submits successfully. A disposable RPC proxy rejected the exact test input FAIL; the sheet retained the input and original label and retry then succeeded. Evidence: evidence/rename-rpc.jsonl. The first / #42 submission reflects the automation tool's Unicode typing limitation; the subsequent Unicode paste is the successful full-name check.
- Final 1200×760pt light screenshot in the chat verified 28/22pt compact tab layout, straight nested split joins, bottom-right curve, focused close control and six original-color icons with a real terminal attachment. Header close-button right-click exposed the existing pane menu including Close Pane. Native AX exposes the close control as a button.
- The first synthetic-agent fixture could not attach: metadata claimed Agents that did not exist on Herdr. Final fixture separates the real PTY device from the synthetic icon metadata device; no production app logic was changed to accommodate the fixture.
- Native asset rendering caught a CoreSVG parser incompatibility in compact arc flags (Gemini rendered a fragment). Expanding path commands with svg.path and normalizing em dimensions fixed the rendered original-color vector. Source URLs/adapted hashes and license remain in Resources/Icon/AgentIcons.json and Resources/Licenses/LobeIcons.txt. Reproduce with scripts/refresh-agent-icons.py in an environment with svg.path; this is not a runtime dependency.

## Limits and handoff

No installed production application was replaced. The review bundle is build/ui-five/HerdrX UI Five.app, with an isolated bundle ID, preferences and state directory. Only the independently named herdrx-ui-five-20261010 session was used for mutations. Earlier acceptance reports remain historical.

Live VoiceOver, reduced-motion timing, continuous pointer traversal, dark/full-screen/hidden-sidebar variants, exact native traffic-light center, 1× displays and older macOS remain manual checks. The existing ⌘⇧W mapping is covered by source/Core tests; late-stage computer-use keyboard/activation did not reliably dispatch it, so no successful live keyboard-close execution is claimed. Full pixel-perfect/window-system acceptance is not asserted.

The isolated app, RPC proxy and named test server were stopped after verification; source, review bundle and evidence are retained.
