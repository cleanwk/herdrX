# Selection and theme validation — 0.1.13

Scope: the supplied 2026-10-12 audit of 0.1.12, implemented on top of 668e50c. No new Agent launch, independent Shell, file tree, transfer or ACC integration.

## Behavior and evidence

The six native integration tests passed on macOS at commit `da1c86097bab0152f8ea9a965b46458cf5b7fc82` in [CI run 38220520404](https://github.com/cleanwk/herdrX/actions/runs/38220520404). The color test covers 198 family/appearance/accent combinations, including state contrast and independence from the selected accent. Captured links are checked twice at the same pointer location to exercise the pinned embedded adapter's coordinate deduplication.

Production sources: `App/SelectionTerminalView.swift`, `Theme.swift`, `ThemeColors.swift` and their native consumers. The pinned libghostty-spm 1.6.20260909 uses upstream 82938b633ba6. Its `toggle_mouse_reporting` action suppresses reports without injecting Shift; `mouseCaptured()` reflects the TUI request, not the host's reporting preference. The host keeps those two facts separate. Configuration changes cancel an active gesture before updating mounted surfaces.

`Tests/SelectionTests.swift` compiles the production selection view, theme and localization in a hostless macOS test bundle. It uses a real Ghostty InMemoryTerminalSession, native window, pasteboard readback and captured input bytes. It does not launch the normal GUI or attach to a user's Herdr service. Preferences and pasteboard data are saved/restored inside the test process. This is engine integration evidence, not physical-mouse or live-Agent acceptance.

| Check | Status |
| --- | --- |
| Python release/tap/appcast contracts | PASS: 6 tests on Linux |
| macOS universal app build, Core, PTY, tab, text-input and geometry checks | Required current-head gate: [PR #19 checks](https://github.com/cleanwk/herdrX/pull/19/checks); all must pass before merge/tag |
| Consecutive ASCII/Chinese selection, clipboard unchanged while dragging, on/off reporting and capture, selection cleared after copy | PASS: macOS engine suite, run 38220520404 |
| DEC 1000/1002/1003 pending/click/drag input isolation | PASS: macOS engine suite, run 38220520404 |
| Copy off, manual copy, empty copy, hidden-pane cancellation and next anchor | PASS: macOS engine suite, run 38220520404 |
| Real Shift expansion, captured Command-link dispatch, hard lines/indentation/Chinese/emoji and bracketed paste | PASS: macOS engine suite, run 38220520404 |
| Stationary upper/lower edge growth for >1s, release/focus cancellation stops | PASS: macOS engine suite, run 38220520404 |
| Every family/appearance/accent role contrast and normal text independence; mounted content retained across theme update | PASS: macOS engine suite, run 38220520404 |
| Physical mouse, user's actual Agent attach, Herdr history and alternate screen, full app light/dark A/B, actual IME and VoiceOver output | NOT_RUN: Linux editing environment; macOS CI supplies engine checks only |
| Universal release, signed archive/feed, metadata and Homebrew cask | Publication evidence is recorded in the [0.1.13 release](https://github.com/cleanwk/herdrX/releases/tag/v0.1.13) after the release workflow and independent verification |

ANSI16 retains the source palette rather than applying a foreground-only contrast correction to slots that can also be backgrounds. Indexed colors beyond those slots, RGB, inverse, OSC/CSI and diff streams are not rewritten. ANSI rendering and full URL/emoji/IME acceptance remain explicitly separate from UI color math. Alternate-screen selection cannot expose history absent from Ghostty's current screen/history.
