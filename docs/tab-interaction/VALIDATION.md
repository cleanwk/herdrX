# Tab contrast and drag feedback

2026-10-14 (Asia/Shanghai).

Inactive tabs now use an opaque theme-derived fill (8% foreground in light appearance, 10% in dark), a one-point neutral outline and contrast-checked labels/counts. Hover increases the blend to 12%/14%. Selected tabs layer 16%/22% accent over the inactive fill and use a stronger accent outline. Geometry remains 28pt/22pt with the existing gaps and text metrics.

The tab view keeps button identity across reorders. The full background, border, title and count move together. A drag follows the pointer horizontally, raises the source with a stronger border and small shadow, opens a dashed destination slot and animates neighbouring tabs for 180ms ease-out. Release uses the existing queued `tab.move`; rollback snapshots use the same stable views. Hit testing uses packed remaining-tab geometry, so wide tabs can pass short tabs at either end. Reduce Motion disables interpolation. Escape, window deactivation, changed tab order/scope, source deletion and loss of write access cancel the gesture. Edge scrolling is bounded horizontally and stops on cancellation.

## Validation

- Linux: Swift tree-sitter syntax checks passed for the edited tab and color code and native harness. This is not Swift type checking or AppKit rendering.
- `scripts/TabScrollTests.swift` now exercises right/left moves of a 200pt tab beside short tabs, stable button identity, unchanged selection, click jitter, return-to-origin, Escape, offline/source-removal/order-change/window cancellation, and edge-scroll cancellation. Existing containment, context-menu, count and geometry cases remain.
- The native theme matrix checks inactive tab labels against both inactive surfaces, in addition to its selected-text checks.
- The complete macOS workflow passed at `535ef1189c8b1a22b148a5b41b2182641689680f`: 65 Core tests, native Ghostty selection/theme tests, real Herdr fixtures, universal build, PTY, drag/input harnesses and packaging. [Native check excerpts](evidence/native-checks.txt) and the [CI run](https://github.com/cleanwk/herdrX/actions/runs/38527987630) record the result. The later read-only-click regression and documentation are covered by the [current PR head checks](https://github.com/cleanwk/herdrX/pull/28/checks).
- The native control's [light](evidence/light.png) and [dark](evidence/dark.png) captures use production `ThemeColors` with the default palette seeds. Both were inspected for fill, outline and selected/inactive hierarchy. They are isolated-control captures, not running-app or physical drag/trackpad acceptance.

No installed application, user preferences, Herdr session or release was changed by this validation.

## Window drag conflict and simplified tab menu — 2026-10-16

The tab strip and its borderless buttons now explicitly return `false` from
`mouseDownCanMoveWindow`. The workbench enables background window dragging;
tab presses must remain with the tab controls so their existing horizontal drag
preview and queued `tab.move` can complete. The window's background-drag setting
is unchanged. Tab context menus now contain Rename Tab and Close Tab only, with
the directional move items and their English/Simplified Chinese strings removed.

The native harness now uses a transparent titled, full-size-content window with
background dragging enabled. Mouse down, drag and release go through
`NSWindow.sendEvent`, instead of calling the strip handlers directly. Assertions
cover unchanged window position, forward/backward ordering, dragging from pill
padding and the pane-count slot, selection, cancellation, and overflow scrolling.
Single-tab, multi-tab and offline menus retain their target and availability checks.

Validation for this change:

- PASS: tree-sitter Swift syntax parsing for `App/Tabs.swift` and
  `scripts/TabScrollTests.swift`; this is not Swift type checking.
- PASS: English/Simplified Chinese localization key parity, removal of directional
  move strings, and preservation of Rename Tab/Close Tab strings.
- PASS: `git diff --check`.
- BLOCKED: `scripts/test-tabs.sh` exited at compilation with
  `xcrun: command not found` on this Linux executor. The updated native harness,
  macOS build, physical mouse/trackpad dragging and running-app acceptance have
  not been run for this change. Earlier macOS evidence above applies only to the
  earlier source revisions.

No installed application, Herdr session or release was changed.

The 0.1.19 release also runs this harness on macOS through [PR #30 checks](https://github.com/cleanwk/herdrX/pull/30/checks); the current head must pass before merging and tagging. The Linux limitation above describes the initial local pass, not a waiver of native CI. Physical mouse/trackpad acceptance remains separate.
