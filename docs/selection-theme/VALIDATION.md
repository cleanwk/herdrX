# Selection and theme validation — 0.1.13

Scope: the supplied 2026-10-12 audit of 0.1.12, implemented on top of 668e50c. No new Agent launch, independent Shell, file tree, transfer or ACC integration.

## Behavior and evidence

Production sources: `App/SelectionTerminalView.swift`, `Theme.swift`, `ThemeColors.swift` and their native consumers. The pinned libghostty-spm 1.6.20260909 uses upstream 82938b633ba6. Its `toggle_mouse_reporting` action suppresses reports without injecting Shift; `mouseCaptured()` reflects the TUI request, not the host's reporting preference. The host keeps those two facts separate. Configuration changes cancel an active gesture before updating mounted surfaces.

`Tests/SelectionTests.swift` compiles the production selection view, theme and localization in a hostless macOS test bundle. It uses a real Ghostty InMemoryTerminalSession, native window, pasteboard readback and captured input bytes. It does not launch the normal GUI or attach to a user's Herdr service. Preferences and pasteboard data are saved/restored inside the test process. This is engine integration evidence, not physical-mouse or live-Agent acceptance.

| Check | Status |
| --- | --- |
| Python release/tap/appcast contracts | Pending local run |
| macOS universal app build, Core, PTY, tab, text-input and geometry checks | Pending CI |
| Consecutive ASCII/Chinese selection, clipboard unchanged while dragging, on/off reporting and capture, selection cleared after copy | Pending CI |
| DEC 1000/1002/1003 pending/click/drag input isolation | Pending CI |
| Copy off, manual copy, empty copy, hidden-pane cancellation and next anchor | Pending CI |
| Stationary upper/lower edge growth for >1s, release/focus cancellation stops | Pending CI |
| Every family/appearance/accent role contrast and normal text independence; mounted content retained across theme update | Pending CI |
| Physical mouse, user's actual Agent attach, Herdr history and alternate screen, full app light/dark A/B, actual IME and VoiceOver output | NOT_RUN: Linux editing environment; macOS CI supplies engine checks only |
| Universal release, signed archive/feed, metadata and Homebrew cask | Pending release |

ANSI16 retains the source palette rather than applying a foreground-only contrast correction to slots that can also be backgrounds. Indexed colors beyond those slots, RGB, inverse, OSC/CSI and diff streams are not rewritten. ANSI rendering and full URL/emoji/IME acceptance remain explicitly separate from UI color math. Alternate-screen selection cannot expose history absent from Ghostty's current screen/history.
