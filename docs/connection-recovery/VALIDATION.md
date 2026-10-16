# Connection recovery and tab containment

Date: 2026-10-10. Native macOS, Herdr 0.9.3 / protocol 22.

## Contract

HerdrX remains a GUI for Herdr. Start Herdr invokes the existing `herdr server` or `herdr --session <name> server` command on request. The server owns persisted sessions and processes. Only canonical default/named socket paths map to a launch; arbitrary paths and remote devices do not. A validated server snapshot establishes readiness, including the [scoped-read compatibility path](scoped-snapshots.md) after an aggregate response truncates.

The sidebar shows a short status and action, with guidance and selectable diagnostics behind an accessible info button. The empty canvas centers the same recovery group. The 28pt tab bar contains 22pt pills, with 3pt vertical insets, and only horizontal overflow can scroll.

## Automated checks

- 28 Core tests pass, including six connection tests: missing socket with typed errno; stopped versus permission/remote errors; SSH authentication versus retryable network failures; canonical/default/named session mapping; missing CLI; captured CLI arguments/environment and nonzero exit diagnostics.
- `scripts/test-tabs.sh` compiles the production AppKit tab view directly. It checks vertical lock, horizontal/diagonal/Shift wheel input, propagation from tab buttons, clamped boundaries, selected-tab reveal, resize, and short/empty strips. It asserts the 28/22/3pt geometry. Events are delivered only to an offscreen view, never posted to the system.
- Debug arm64 app builds. Existing PTY checks pass, including foreground interruption and 20 restart generations. Six Python packaging/update tests pass.
- README is English, 72 lines, with valid repository-relative links. Final required universal build and package checks are enforced by PR CI.

## Native checks

Used a separate `HerdrX Recovery.app` bundle and `HERDRX_STATE_DIR` under ignored `build/connection-review/`, plus the disposable named server `herdrx-recovery-20261010`. Fixture labels are synthetic; CLI startup, RPC, tabs and terminal attachment are real. Production device configuration and installed application were not used as test fixtures.

- At the 200pt sidebar minimum, stopped state uses a neutral dot, concise text and Start Herdr. A missing custom socket and invalid named path show Session unavailable and Connections instead of launching a guessed target.
- Current Chinese/light and English/dark captures show unclipped actions and a centered empty state. The details popover opens with complete wrapped paths and native selectable text. Connections opens the Connections page, including via accessibility activation.
- Start Herdr restores the named server and real terminal workspace. Repeated activation produces one startup. The settings-page action uses the same flow. Stopping and restarting the fixture restores the persisted workspace. Quitting the client leaves the server running, confirmed with `herdr --session herdrx-recovery-20261010 status server`.
- Fourteen fixture tabs overflow horizontally. Selecting the last tab reveals it without vertical displacement. Tabs remain visually centered after attempted native up/down scroll input. The computer-use driver did not visibly move the strip with horizontal wheel input, so this is **not** claimed as physical-trackpad acceptance; the deterministic AppKit regression establishes the wheel behavior.
- A pre-validation fixture exercised native CLI startup failure and retained its details/action. The final implementation rejects that invalid session name before launch; final failed-process/missing-CLI coverage is automated.

## Review and limits

Inline finish review substituted for a separate reviewer; no subagent was delegated. No web detector ran for this native surface. [Finish review and verdict](FINISH-REVIEW.md) records the scoped visual outcome.

Source review verifies captured endpoint/generation checks before launch and after awaits, duplicate-start suppression, a bounded readiness deadline, preservation of failure details, and existing reconnect backoff without a fake countdown. Editing/removing a device during startup, physical trackpad momentum, VoiceOver narration, live SSH/Tailcat failures and older macOS are not claimed as runtime-tested. No new shipping raster assets were added; evidence PNGs are captures of the isolated native app, not product assets.

## Captures

- [Chinese, light, stopped](evidence/stopped-zh-light.png)
- [English, dark, stopped](evidence/stopped-en-dark.png)
- [Overflow tabs, light](evidence/tabs-overflow.png)
