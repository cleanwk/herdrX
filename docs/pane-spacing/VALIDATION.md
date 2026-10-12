# Pane spacing validation

> Historical geometry. The 0.1.14 [thin pane contract](../pane-spacing/0.1.14.md) supersedes spacing and border weight below; these screenshots predate that change.

2026-10-10. Reference: installed native Herdr GPUI 20261008.1, observed without changing its sessions. Test mutations used only `herdrx-pane-gutters-20261010` with an isolated `HERDRX_STATE_DIR` and uniquely named debug bundles. Real Herdr RPC, PTY and Ghostty surfaces; fixture workspace labels are test data.

## Final geometry

- Keep the existing 28pt tab bar / 22pt pills / 4pt tab gaps.
- Remove the additional 6pt band below tabs. Every pane has the same approximately 11pt top-border/title reserve, which supplies the top perimeter clearance without stacking another inset.
- Keep 8pt left, right and bottom margins regardless of sidebar visibility. Pane outlines no longer meet the window edge. All corners are square, matching the native reference's independent rectangular panes.
- Apply 4pt on each side of an internal boundary, producing an 8pt frame-to-frame gutter. Stacked outlines also include the following pane's 11pt title reserve, as in the observed native vertical rhythm.
- Use 1.5pt outlines at 2×; quantize to 2pt at 1× to align both stroke edges to backing pixels. Accent focus and 28% foreground neutral outlines remain distinct.
- Preserve authoritative Herdr rectangles and existing resize RPC. Split minimums account for gutters, and 7pt drag targets stay in the gaps.

## Completed checks

- Debug arm64 app build passed.
- `scripts/test-panes.sh`: production geometry compiled directly; single, two-column, stacked, T and grid layouts; fractional resize sizes; no overlap; exact 8pt gutters; stroke containment and backing-pixel alignment at 1×/2×; tiny-frame safety.
- `scripts/test-tabs.sh`: native AppKit vertical lock, horizontal/diagonal/Shift input, resize, reveal, boundary clamp, empty/short strips and 28/22/3pt dimensions passed.
- Native light Chinese at 1200×760 and dark English at 980×620: all four perimeter sides visible, independent four-pane borders, truncated long titles clear of controls, sidebar separation and compact tab-to-pane spacing.
- Sidebar hidden + zoomed single pane retains left/right/bottom margins; restore and Tab switching work. Native debug diagnostics report 923×723pt canvas at 1200×760 with sidebar, 1184×723 without it, and 703×583 at 980×620 with sidebar.
- Horizontal gutter drag updated the existing Herdr layout ratio from 50% to 54.196304% in the final build. Vertical drag and title right-click Close Pane were also verified during the same implementation pass.

## Evidence

- [Four panes, light](evidence/perimeter-four-light.png)
- [Four panes, dark/minimum window](evidence/perimeter-four-dark.png)
- [Two panes, dark](evidence/perimeter-two-dark.png)
- [Single pane, sidebar hidden](evidence/perimeter-single-hidden-light.png)
- [Native layout/geometry record](evidence/geometry.json)

The disposable GUI was closed and only the named test server was stopped after verification.

These are current running-app captures, not mockups. The native reference informed pane spacing and square independent borders; HerdrX keeps its requested compact tabs, title/close chrome and themes. Pixel identity with the entire Herdr window is not claimed. No new shipping raster assets were added.

## Limits

Physical 1× display, full-screen transitions, VoiceOver traversal, older macOS, live SSH/Tailcat and every font/theme combination were not exercised in this pass. The geometry test covers 1× stroke arithmetic, not a physical display capture. CI and publication are verified separately.
