# Pane scrolling — 0.1.15

2026-10-12 (Asia/Shanghai). Fix normal up/down scrolling in Agent panes without changing text selection, client ownership or authoritative Herdr history.

## Findings and contracts

The default `mouse-reporting=false` preference disabled wheel reports as well as clicks. Herdr's interactive attachment renders the remote viewport in an alternate screen; scrolling the local Ghostty viewport therefore cannot retrieve the server history. A separate 0.1.14 recovery path disabled the attachment's DEC mouse modes after Agent exit, also preventing later scrolling.

Verified in Herdr 0.9.3 (`7b116c05bfda646af39d2524c54e70c751f57ee8`): `src/client/attach.rs` converts SGR wheel reports into supported AttachScroll messages. `src/server/pane_input.rs` chooses server history, the child TUI's requested mouse protocol or alternate-scroll behavior. No parallel input protocol or pane.scroll mutation is introduced. libghostty-spm 1.6.20260909 supplies scroll delta accumulation, precision/momentum forwarding and mouse encoding.

The selection host temporarily enables reporting only around an idle wheel event, refreshes position/modifiers while reporting is disabled to avoid hover input, and restores the saved preference. Existing selection gestures keep their local behavior. Shell recovery resets keyboard/focus state while preserving the live attachment's mouse modes. Detach/restart still perform the full cleanup.

Herdr 0.9.3 observers receive live ANSI viewport frames, do not read stdin, and do not expose an independent history viewport. The read-only banner now states that scrolling needs Reconnect or explicit Take Control. Read-only wheel input is blocked; no automatic takeover or shared pane.scroll request is used to simulate private observation scrolling.

## Regression coverage

- Real native NSEvent wheel events through the production SelectionTerminalView and Ghostty: discrete up/down, small precise deltas and momentum in both directions, reporting preference on/off, no extra hover or arrow-key input, drag/copy and click ownership after scrolling.
- Real Ghostty local scrollback up/down; attached keyboard recovery preserves wheel reporting; observation suppresses wheel and reconnect permits it again. Existing full recovery still clears stale mouse/keyboard state while retaining text history and bracketed paste.
- Production ByteProcess with the official Herdr binary in an isolated named session: up/down SGR wheel moves server scroll offsets, and reaches a synthetic alternate-screen mouse-aware TUI with matching position and direction. Existing coexistence checks cover refusal of implicit takeover, live observation, independent observer dimensions, rapid restarts and preservation of the server shell.
- Required current-head CI also runs Core, universal app build, PTY stress, tab containment, text input, geometry and packaging checks.

CI results are tracked on the fix PR; all required checks must pass before tagging. These are native engine/real transport checks with a synthetic TUI, not physical trackpad testing or a claim of live Claude/Codex acceptance. User hardware, third-party GUI combinations and SSH/Tailcat remain unverified. Publication and installation remain separate.
