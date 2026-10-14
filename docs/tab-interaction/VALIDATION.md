# Tab contrast and drag feedback

2026-10-14 (Asia/Shanghai).

Inactive tabs now use an opaque theme-derived fill (8% foreground in light appearance, 10% in dark), a one-point neutral outline and contrast-checked labels/counts. Hover increases the blend to 12%/14%. Selected tabs layer 16%/22% accent over the inactive fill and use a stronger accent outline. Geometry remains 28pt/22pt with the existing gaps and text metrics.

The tab view keeps button identity across reorders. The full background, border, title and count move together. A drag follows the pointer horizontally, raises the source with a stronger border and small shadow, opens a dashed destination slot and animates neighbouring tabs for 180ms ease-out. Release uses the existing queued `tab.move`; rollback snapshots use the same stable views. Hit testing uses packed remaining-tab geometry, so wide tabs can pass short tabs at either end. Reduce Motion disables interpolation. Escape, window deactivation, changed tab order/scope, source deletion and loss of write access cancel the gesture. Edge scrolling is bounded horizontally and stops on cancellation.

## Validation

- Linux: Swift tree-sitter syntax checks passed for the edited tab and color code and native harness. This is not Swift type checking or AppKit rendering.
- `scripts/TabScrollTests.swift` now exercises right/left moves of a 200pt tab beside short tabs, stable button identity, unchanged selection, click jitter, return-to-origin, Escape, offline/source-removal/order-change/window cancellation, and edge-scroll cancellation. Existing containment, context-menu, count and geometry cases remain.
- The native theme matrix checks inactive tab labels against both inactive surfaces, in addition to its selected-text checks.
- Native harness execution, macOS build and visual/animation acceptance are pending the current-head macOS CI run. No native screenshot from an earlier revision accepts these changes.

No installed application, user preferences, Herdr session or release was changed by this validation.
