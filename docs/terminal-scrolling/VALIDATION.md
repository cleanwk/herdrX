# Pane scrolling — 0.1.15

## 2026-10-14: stale mouse capture after program exit

The reported `64;41;27M` / `65;39;27M` fragments are SGR wheel reports, not malformed Chinese encoding. A Linux fixture using the official Herdr 0.9.3 binary, an independent `mouse` session, a separate client state directory and a disposable shell reproduced the complete reports at the shell after leaving DEC 1000/1006 enabled. Herdr's `apply_scroll` follows its cached terminal mouse mode and forwards those reports even when the foreground process has returned to a shell. Local keyboard recovery alone cannot change that server-side state.

Attached wheel gestures now wait for `pane.process_info`. A verified idle shell scrolls through the existing `pane.get` / `pane.scroll` absolute-offset API; its wheel gesture never becomes PTY input. A verified running foreground program retains Ghostty's native wheel encoding, precision, direction and modifiers. Requests serialize per terminal, trackpad fractions survive batches, and offsets clamp to server history. Device, connection, pane/terminal and attachment identities are checked after asynchronous work. Hidden/restarted terminals cancel pending gestures; observers and failed/missing process verification never replay a wheel. This uses no new protocol, reset command, takeover or screen/history clearing.

The same isolated fixture confirmed offsets 0 → 3 → 0 under stale mouse capture. The production coexistence fixture now checks that this path preserves retained output. Core cases cover fractional/reversed motion and offset limits; native Ghostty cases cover the wheel gate, explicit TUI forwarding and observer rejection. Local Linux Python checks passed (14), the real coexistence fixture passed, and syntax/whitespace checks passed. The full [macOS workflow](https://github.com/cleanwk/herdrX/actions/runs/38527987630) passed at `535ef1189c8b1a22b148a5b41b2182641689680f`, including all terminal changes. See [current-head checks](https://github.com/cleanwk/herdrX/pull/28/checks) for the final PR gate.

The official Codex CLI 0.162.1 was also installed locally and launched inside disposable zsh/Herdr panes (`--no-daemon`, read-only sandbox, separate Codex state, an unused local model-provider fixture; no user credentials or model request). In its default alternate-screen mode, SIGTERM followed by two wheel events reproduced the exact visible `64;41;27M65;39;27M` fragments at the zsh prompt and left the partially drawn Codex input region. This is a real Codex reproduction, separate from the explicitly seeded mode fixture. The comparison with `--no-alt-screen` left partial prompt output but did not leak the wheel reports.

The wheel gate addresses new report leakage in both cases. Recovery of the server's stale alternate screen remains an upstream capability gap: Herdr 0.9.3 exposes no non-destructive terminal-mode reset API. Its `pane.clear` implementation explicitly does nothing on the alternate screen and otherwise erases history, so it cannot safely restore this case. No automatic clear, restart, shell-command injection or local alternate-screen toggle was added. The macOS application and the user's exact prior version remain outside the Linux reproduction; residual full-screen rendering is not claimed fixed.

The earlier validation below records the original attach-wheel behavior; the verified-shell routing above supersedes it for shells only.

2026-10-12 (Asia/Shanghai). Fix normal up/down scrolling in Agent panes without changing text selection, client ownership or authoritative Herdr history.

## Findings and contracts

The default `mouse-reporting=false` preference disabled wheel reports as well as clicks. Herdr's interactive attachment renders the remote viewport in an alternate screen; scrolling the local Ghostty viewport therefore cannot retrieve the server history. A separate 0.1.14 recovery path disabled the attachment's DEC mouse modes after Agent exit, also preventing later scrolling.

Verified in Herdr 0.9.3 (`7b116c05bfda646af39d2524c54e70c751f57ee8`): `src/client/attach.rs` converts SGR wheel reports into supported AttachScroll messages. `src/server/pane_input.rs` chooses server history, the child TUI's requested mouse protocol or alternate-scroll behavior. No parallel input protocol or pane.scroll mutation is introduced. libghostty-spm 1.6.20260909 supplies scroll delta accumulation, precision/momentum forwarding and mouse encoding.

The selection host temporarily enables reporting only around an idle wheel event, refreshes position/modifiers while reporting is disabled to avoid hover input, and restores the saved preference. Existing selection gestures keep their local behavior. Shell recovery resets keyboard/focus state while preserving the live attachment's mouse modes. Detach/restart still perform the full cleanup.

Herdr 0.9.3 observers receive live ANSI viewport frames, do not read stdin, and do not expose an independent history viewport. The read-only banner now states that scrolling needs Reconnect or explicit Take Control. Read-only wheel input shows a pane-local explanation even if another pane has focus; no automatic takeover or shared pane.scroll request is used to simulate private observation scrolling.

## Regression coverage

- Real native NSEvent wheel events through the production SelectionTerminalView and Ghostty: discrete up/down, small precise deltas and momentum in both directions, reporting preference on/off, no extra hover or arrow-key input, drag/copy and click ownership after scrolling.
- Real Ghostty local scrollback up/down; attached keyboard recovery preserves wheel reporting; observation suppresses wheel and reconnect permits it again. Existing full recovery still clears stale mouse/keyboard state while retaining text history and bracketed paste.
- Production ByteProcess with the official Herdr binary in an isolated named session: up/down SGR wheel moves server scroll offsets, and reaches a synthetic alternate-screen mouse-aware TUI with matching position and direction. Existing coexistence checks cover refusal of implicit takeover, live observation, independent observer dimensions, rapid restarts and preservation of the server shell.
- Required current-head CI also runs Core, universal app build, PTY stress, tab containment, text input, geometry and packaging checks.

Native wheel/selection tests (9) and production Herdr scroll/coexistence tests passed at `a346e78fa68b412fa611729a98b7386d7ee10b83` in [CI run 38230758601](https://github.com/cleanwk/herdrX/actions/runs/38230758601). The final current-head gate is [PR #21](https://github.com/cleanwk/herdrX/pull/21/checks); all required checks must pass before tagging. These are native engine/real transport checks with a synthetic TUI, not physical trackpad testing or a claim of live Claude/Codex acceptance. User hardware, third-party GUI combinations and SSH/Tailcat remain unverified. Publication and installation remain separate.
