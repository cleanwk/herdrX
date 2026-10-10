## verdict

All 12 required captures were reopened at the same paths used in the finish review and remain valid. This pass scores only F1–F4 from [FINISH-REVIEW.md](FINISH-REVIEW.md); it is not a new full-surface audit.

- **F1 — resolved.** Light, dark and compact workbench recaptures show the corrected sidebar width, shared text alignment, taller Agent rows and increased pane-top clearance. `Workbench.swift` now uses 260pt default/reset, 36pt combined text inset, 6.5pt Space and 9.5pt Agent vertical padding, and 6pt additional canvas-top clearance, producing the approximately 45pt/51pt rows and 42pt first-pane outline requested. The 28pt tab row and 13pt/11pt sidebar type remain. `DIRECTION.md` correctly identifies the original 3840 × 2100 workbench as 2×, and saved custom sidebar widths remain authoritative.
- **F2 — resolved.** `settings-appearance.png` and `settings-appearance-dark.png` show the palette/accent/language stack moved into the reference rhythm without moving the theme control or x≈83pt field start. The 7pt outer and 4pt inner spacing remove the prior cumulative approximately 7pt language-row drift.
- **F3 — resolved.** `PreferenceMenu.updateNSView` compares only non-separator menu items, preserving the separator while avoiding unchanged-menu reconstruction. [theme-menu.json](evidence/theme-menu.json) records 14 consecutive successful native selections without retries during normal isolated Herdr polling. The recaptures show Catppuccin light and Tokyo Night dark; this does not certify the visual quality of every palette.
- **F4 — resolved.** `PRODUCT.md`, `DESIGN.md`, `.impeccable/design.json` and the workbench surface brief now describe the current ACCM authority, corrected dimensions, six settings tabs, switchable themes and removal of independent Shell/Terminals entry points while preserving Space sessions. The README no longer promises an automatic standalone Shell. The documents distinguish synthetic fixture content, actual PTY/RPC operations, inspected palettes and untested runtime environments, and make no pixel-identity or new-release claim.

## remaining

Clear. No material regression caused by this fix batch was found in the recaptures or the scored source/document changes. This ship verdict covers the four scored fixes only; the original review's stated verification limits remain.

disposition: ship
