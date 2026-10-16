# Terminal input recovery

2026-10-12 (Asia/Shanghai). Follow-up to 0.1.15 for CSI u fragments on opening a terminal and on pressing Ctrl-C.

## Cause and behavior

Herdr 0.9.3 synchronizes a pane's cached keyboard protocol into every direct attachment (`src/server/headless/render.rs`, `src/client/mod.rs`, `src/terminal_modes.rs`). Its direct input path forwards keyboard bytes unchanged (`src/server/pane_input.rs`). A shell left with stale Kitty flags therefore gets CSI u sequences, including Ctrl-C press/release events, immediately on attachment. The GUI previously checked recovery only after detected Agent exit or a menu action; ordinary Ctrl-C was encoded by Ghostty like any other key.

The production output path now observes Kitty/modifyOtherKeys activation, including control sequences split across reads, and requests the existing verified-shell recovery. It never rewrites or stores screen output in observable UI state. The monitor belongs to one attachment; delayed callbacks cannot repair a replacement attachment. Foreground process information, rather than potentially stale Agent metadata, determines whether recovery is safe. Existing device, pane, terminal, connection and attachment checks still apply after RPC.

The native terminal view routes plain physical Ctrl-C to ETX and consumes the corresponding C and Control releases, even if Control is released first. Repeated presses still reach the process while verification is pending. Other shortcuts and IME composition use native handling. Missing releases after focus changes cannot suppress a later ordinary key release; a reconnect has its own recovery coalescing token. The interrupt does not itself clear a running TUI's keyboard modes; local recovery waits for a verified shell. The live attachment retains mouse capture for history/TUI scrolling, screen content and bracketed paste. No shell repair command is injected, server session replaced, or controller taken over.

## Validation

- Core regression tests cover every byte boundary of keyboard negotiation, multiple controls, reset/query/text rejection and bounded malformed input recovery.
- Native Ghostty tests cover physical Ctrl-C under Kitty flags 7/31 and modifyOtherKeys, repeated presses, C release after Control release, declined handlers, other shortcuts, retention of a live TUI protocol and normal input after keyboard recovery. Existing wheel, selection, history and bracketed-paste regressions remain in the same target.
- Production ByteProcess/Herdr fixture seeds stale Kitty state before the first attachment, verifies that negotiation is detected while the actual foreground is a shell, and sends raw Ctrl-C. The fixture retains existing controller ownership, observation, scrolling and running-process checks.
- Local Linux: Python release/appcast tests (6), existing isolated Herdr coexistence fixture and whitespace validation passed. A separate disposable PTY reproduction confirmed initial `CSI >7u` negotiation at an idle shell, injected Kitty Ctrl-C press/release fragments, sent raw ETX, and successfully executed the next command without changing the shell PID.
- Native compilation and interaction run on the repository's macOS CI runner. The production Herdr and pane geometry steps passed at `61476c0`; the authoritative current-head gate is [PR #22 checks](https://github.com/cleanwk/herdrX/pull/22/checks), including Core, Ghostty, coexistence, PTY, tab/input, universal build and packaging.

## Limits

The user's physical Mac and exact prior shell state are unavailable here. These tests do not establish physical keyboard/trackpad, live Claude/Codex, SSH/Tailcat or third-party GUI acceptance. Historical screen corruption and shell termios settings are not rewritten by local keyboard-mode recovery. A code change, a packaged CI preview and an installed release are distinct outcomes.

## Doubao asynchronous composition — 0.1.19

2026-10-16 (Asia/Shanghai). Affected baseline: 0.1.18 / build 19,
`a4c08fb7ee63166bd9605f0a0fc950f97c4b0598`.

`TerminalView.selectedRange()` now always returns `{0,0}`. Previously the host
returned Ghostty's preedit caret while composing, causing the insertion point to
change from `{0,0}` to `{2,0}` for `你好` and back. An asynchronous dictation client
comparing those ranges could abandon its final commit. `markedRange()` still
delegates to Ghostty during composition and returns `{0,0}` otherwise.

The adapter stays in `App/Terminal.swift`. No libghostty-spm source, version or
fork changes are involved. `setMarkedText`, `unmarkText`, `insertText`, `firstRect`,
shortcut dispatch and Ghostty surface lifecycle remain unchanged.

The hostless native test target now compiles the production App sources except
the application entry point and resources. It does not launch HerdrX, the updater
or a Herdr service. The existing fixture uses the real `TerminalView`, controller,
Ghostty surface and `InMemoryTerminalSession` write callback. New cases cover:

- No composition: no marked text and both ranges `{0,0}`.
- `setMarkedText("你好", selectedRange: {2,0}, replacementRange: {NSNotFound,0})`:
  selected range `{0,0}`, marked range `{0,2}` and no committed session bytes.
- `unmarkText()`: no marked text and both ranges `{0,0}` again.
- A supplementary-plane character (`你好🌏`): marked range uses four UTF-16 units.
- After an asynchronous delay, `insertText("你好世界", replacementRange:
  {NSNotFound,0})` clears preedit, preserves the insertion point and sends exactly
  the final UTF-8 bytes through the session callback without replacing the surface.

The async test establishes `NSApp.currentEvent` using an `applicationDefined`
event posted to and retrieved from AppKit's event queue. It does not fake keyDown,
call `session.sendInput` for the expected text, or bypass the adapter's event guard.

Validation:

- The [old-implementation run](https://github.com/cleanwk/herdrX/actions/runs/38863191033) at `f46966d850c2cda0d30455a5c47562fc5404543e` failed exactly four insertion-range assertions in the two new tests; the 14 existing native tests passed. The reported range was `{2,0}` instead of `{0,0}`. [Baseline excerpts](evidence/dictation-baseline.txt) preserve the failure evidence. The marked-range, cancellation, current-event, committed-byte and surface assertions did not fail.
- Local Swift syntax parsing, release-version consistency, unchanged Ghostty pin, `git diff --check`, shell syntax and all 14 Python release/appcast tests passed.
- The corrected implementation and tab fix must pass all [current PR #30 checks](https://github.com/cleanwk/herdrX/pull/30/checks) before merge/release, including native tests, Core, Herdr fixtures, universal build and packaging.
- Physical Doubao speech input remains NOT_RUN here.
