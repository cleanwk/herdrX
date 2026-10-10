# Pane window-corner validation

2026-10-11. Isolated debug bundles, `HERDRX_STATE_DIR=build/corner-review/state`, and disposable Herdr session `herdrx-pane-corners-20261011`. Running-app captures use real Herdr layouts, PTYs and Ghostty surfaces on macOS 27.0.1 at 2×. Fixture names are test data.

## Geometry contract

- Preserve the 28pt tab bar, 22pt pills, 8pt pane gutters, 8pt side/bottom perimeter insets and existing top title clearance.
- Curve only the bottom corners nearest the window. A visible sidebar removes the left outer corner; upper panes and internal split corners remain square. Full screen uses square corners.
- Read public SwiftUI [resolved corner radii](https://developer.apple.com/documentation/swiftui/geometryproxy/concentriccornerradii) on macOS 27, or [container corner insets](https://developer.apple.com/documentation/swiftui/geometryproxy/containercornerinsets) on macOS 26. Older systems use a nominal 10pt window radius minus the 8pt perimeter inset.
- Draw the continuous contour using `UnevenRoundedRectangle`, converted to AppKit coordinates. Inset the radius by half the stroke width for the outline, and by the 4pt content inset for the terminal mask. Clamp at zero.
- On the tested system, native geometry reports an 8pt inner radius: the 1.5pt outline centerline uses 7.25pt; terminal content uses 4pt. No private window API or new Herdr protocol is introduced.

## Completed checks

- Local arm64 Debug build passed. Production geometry and continuous paths compile directly in `scripts/test-panes.sh`.
- Geometry tests cover single, columns, stacked, T and grid layouts; resize; exact gutters; 1×/2× stroke alignment; selective bottom-corner ownership; sidebar/full-screen exclusions; radius inset/clamping; actual path containment at outer, top and internal corners.
- Light, sidebar hidden, two panes at 1200×760: both exterior bottom corners curve smoothly; the two interior bottom corners remain square.
- Dark, sidebar shown, grid at the 980×620 minimum: only the window-adjacent bottom-right corner curves. Internal grid corners remain square and all four perimeter gaps remain visible.
- Sidebar toggling updates native radii between `[0, 8]` and `[8, 8]`. Zoomed single-pane view retains both curves and the same margins.
- Actual native full-screen entry reports `[0, 0]` and square bottom corners; exit restores `[8, 8]` at the original window size. The full-screen capture had unrelated white areas around the app capture, so it is not used as whole-window visual evidence; the geometry record preserves the actual transition.
- The macOS 26 fallback path was forced through a Debug-only flag on the same macOS 27 host and returned the same windowed radii.
- Closed the isolated GUI and stopped only the named test server after review.

## Evidence and limits

- [Two panes, light, sidebar hidden](evidence/two-hidden-light.png)
- [Four panes, dark, sidebar shown](evidence/grid-sidebar-dark.png)
- [Zoomed pane, dark, sidebar hidden](evidence/zoom-hidden-dark.png)
- [Native window/canvas/corner geometry](evidence/geometry.json)

These are running-app captures, not mockups or shipping assets. An attempted ANSI-background stress command did not visibly reach the test terminal; colored-output mask acceptance is therefore not claimed. Mask geometry is covered by the shared production path tests, and ordinary terminal backgrounds were visually reviewed. Physical 1× hardware, display-to-display movement, macOS 14–26 runtimes, VoiceOver and arbitrary terminal background combinations were not exercised. CI and release verification are separate gates.

## Inline finish review

Disposition: ship. The scoped regression was the square outside bottom corners introduced during the pane-spacing pass. The current implementation restores continuous concentric corners while keeping the accepted four-side spacing, internal straight edges and border weight. The actual native system geometry replaces a uniform guessed radius on current macOS. Outline and content clipping use one small shared path implementation. DESIGN.md, its sidecar and the surface brief record the updated contract. No new domain features, dependencies or raster assets were added. No remaining corner defect was observed in the captured windowed layouts; the runtime limits above remain explicit.
