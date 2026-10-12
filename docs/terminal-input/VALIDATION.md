# Terminal input recovery

2026-10-12 (Asia/Shanghai). Follow-up to 0.1.15 for CSI u fragments on opening a terminal and on pressing Ctrl-C.

## Cause and behavior

Herdr 0.9.3 synchronizes a pane's cached keyboard protocol into every direct attachment (`src/server/headless/render.rs`, `src/client/mod.rs`, `src/terminal_modes.rs`). Its direct input path forwards keyboard bytes unchanged (`src/server/pane_input.rs`). A shell left with stale Kitty flags therefore gets CSI u sequences, including Ctrl-C press/release events, immediately on attachment. The GUI previously checked recovery only after detected Agent exit or a menu action; ordinary Ctrl-C was encoded by Ghostty like any other key.

The production output path now observes Kitty/modifyOtherKeys activation, including control sequences split across reads, and requests the existing verified-shell recovery. It never rewrites or stores screen output in observable UI state. The monitor belongs to one attachment; delayed callbacks cannot repair a replacement attachment. Foreground process information, rather than potentially stale Agent metadata, determines whether recovery is safe. Existing device, pane, terminal, connection and attachment checks still apply after RPC.

The native terminal view routes plain physical Ctrl-C to ETX and consumes the corresponding C release, even if Control is released first. Repeated presses still reach the process while verification is pending. Other shortcuts and IME composition use native handling. The interrupt does not itself clear a running TUI's keyboard modes; local recovery waits for a verified shell. The live attachment retains mouse capture for history/TUI scrolling, screen content and bracketed paste. No shell repair command is injected, server session replaced, or controller taken over.

## Validation

- Core regression tests cover every byte boundary of keyboard negotiation, multiple controls, reset/query/text rejection and bounded malformed input recovery.
- Native Ghostty tests cover physical Ctrl-C under Kitty flags 7/31 and modifyOtherKeys, repeated presses, C release after Control release, declined handlers, other shortcuts, retention of a live TUI protocol and normal input after keyboard recovery. Existing wheel, selection, history and bracketed-paste regressions remain in the same target.
- Production ByteProcess/Herdr fixture seeds stale Kitty state before the first attachment, verifies that negotiation is detected while the actual foreground is a shell, and sends raw Ctrl-C. The fixture retains existing controller ownership, observation, scrolling and running-process checks.
- Local Linux: Python release/appcast tests (6) and whitespace validation passed. Native compilation and interaction require the repository's macOS CI runner; results will be recorded after that gate completes.

## Limits

The user's physical Mac and exact prior shell state are unavailable here. These tests do not establish physical keyboard/trackpad, live Claude/Codex, SSH/Tailcat or third-party GUI acceptance. Historical screen corruption and shell termios settings are not rewritten by local keyboard-mode recovery. A code change, a packaged CI preview and an installed release are distinct outcomes.
