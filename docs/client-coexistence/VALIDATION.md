# Client coexistence and input recovery (0.1.14)

2026-10-12. Scope: keep another GUI controller connected, restore Agent navigation and remove repeated tool text, and safely recover stale input modes after returning to the shell.

## Contracts and changes

Verified against Herdr 0.9.3 (7b116c05bfda646af39d2524c54e70c751f57ee8): `terminal attach` rejects an occupied controller unless `--takeover` is explicitly provided. HerdrX formerly passed that flag on every attachment. Default and Reconnect now omit it; the separate Take Control action confirms ownership transfer. Both paths address the stable terminal ID. Existing controller protocol synchronization is retained.

If interactive attachment ends, HerdrX starts the supported `terminal session observe` CLI using pipes (SSH uses `-T`). ANSI frames are decoded from documented JSON envelopes. Observers send no input, own no terminal, and reconnect their read-only viewport after resize without resizing the server PTY. Explicit reconnect stops observation; delayed output from stopped observer generations is ignored. Closing the GUI stops its client processes only.

The snapshot `agents` array is authoritative; older snapshots without it retain pane-based fallback. Agent records must match the pane's device-local topology and terminal ID. Named Agent sessions are retained even without an active detector field. An empty server list shows a visible explanation rather than hiding the group. Rows retain task/directory, icon, Space and status; tool text is available through help and accessibility.

Recovery queries `pane.process_info`, checks pane identity, positive shell PID, matching foreground process group and a known shell executable. Missing information or an exec-ed Agent fails closed. Device connection, terminal identity and attachment generation are revalidated after RPC. Automatic recovery runs on detected Agent exit; explicit interrupt sends Ctrl-C and waits for the shell. Local bytes clear stacked Kitty modes, modifyOtherKeys and mouse reporting; they contain no shell command or screen/history reset and preserve bracketed paste.

## Verification

- Linux: official Herdr 0.9.3 in an isolated named session, separate XDG config/state and HERDRX_STATE_DIR. Ordinary second controller refused without disconnecting the owner; observer received live output; observer detach preserved owner; explicit takeover preserved the shell PID. `scripts/coexistence-fixture.py` passed.
- Python packaging/update tests: 6 passed; whitespace check passed.
- macOS CI pending: Core contract tests, Ghostty keyboard/mouse/history regression, production ByteProcess + TerminalObservation against the real isolated Herdr session, existing native selection/PTY/tab/input/pane tests, universal build and package.

## Limits

The screenshot's `1:3u` fragments are consistent with stale Kitty release events; it is not proof that the other GUI has a mouse-only bug. HerdrX recovery affects its own emulator, not another GUI's terminal state. Unknown third-party GUI clients, live remote SSH/Tailcat transport, physical input and visual acceptance remain unverified by these tests. Publication and installation are separate outcomes.
