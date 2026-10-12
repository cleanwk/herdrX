# Pane layout origin compatibility

2026-10-12. Investigating a reported first-launch rightward/downward terminal displacement in HerdrX 0.1.15 (16) on a MacBook Air bought in 2021, with macOS reported as 27.01. The supplied screenshot displaces the pane outline/title as well as the terminal content. The Air's actual processor, display configuration and running Herdr version have not yet been confirmed; this is not evidence of an M1 or macOS-specific rendering failure.

## Reproduced defect

`session.snapshot.layouts[].panes[].rect` uses the coordinate system of `layouts[].area`. HerdrX divided absolute pane x/y by the area's width/height without first subtracting the area's x/y. A single pane whose rectangle equals its area therefore started away from the GUI canvas origin and extended beyond its right/bottom edges whenever the server area had a nonzero origin.

Real, disposable Linux server checks found:

| Herdr | Startup area | Single pane rectangle | Original normalization |
| --- | --- | --- | --- |
| 0.8.2 | (26, 1, 94, 39) | (26, 1, 94, 39) | (0.2766…, 0.0256…, 1, 1), clipped |
| 0.9.0–0.9.3 | (0, 0, 120, 40) | (0, 0, 120, 40) | (0, 0, 1, 1), fills canvas |

The normalizer now computes `(pane.x - area.x) / area.width` and the equivalent y coordinate. Widths/heights retain their existing conversion. This preserves authoritative split placement and chrome insets, keeps the zero-origin path unchanged and does not hardcode a sidebar size or display scale. It adds no layout RPC or terminal restart.

`Core/PaneLayoutGeometry` owns the conversion used by `Desk.layoutRects`. Existing opt-in Debug diagnostics also record canvas frame/bounds origin, backing scale and normalized pane rectangles, to distinguish a server-coordinate offset from a host-view/display issue if the Air still reproduces it.

## Verification

- Four Core regression tests cover nonzero sidebar/header origins, nested splits/chrome insets, legacy missing fields and unavailable/zero-size areas.
- The maintained `scripts/layout-origin-fixture.py` starts separate named servers with isolated configuration/state, captures single/column/nested layouts from real Herdr 0.8.2 and 0.9.3, preserves the original terminal while splitting and stops only those fixture servers. The six-case capture passed locally.
- `scripts/test-panes.sh` compiles the production JSON conversion and AppKit point/pixel geometry. It consumes those real snapshots and checks containment, no overlap and full single-pane coverage at 703×583, 996×774 and 1436×870 points, at 1× and 2×. A synthetic 26/1 origin in a 54×23 area exercises the roughly half-canvas displacement seen on a narrower TUI. These are geometry assertions, not physical display captures.
- All 14 existing Python release tests passed locally. macOS Core, geometry, native terminal and full build checks are pending CI.

The legacy-server coordinate defect is reproduced. Its connection to this particular Air remains a hypothesis until the running Herdr version/layout or a corrected build is checked on that machine. No physical Air/Pro comparison, live GUI screenshot acceptance, release or installation was performed here.
