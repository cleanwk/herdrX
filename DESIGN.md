---
name: HerdrX
description: A compact native macOS Space workbench following the ACCM reference, with switchable terminal palettes.
colors:
  catppuccin-light-background: "#EFF1F5"
  catppuccin-light-foreground: "#4C4F69"
  catppuccin-dark-background: "#1E1E2E"
  catppuccin-dark-foreground: "#CDD6F4"
  tokyo-light-foreground: "#4C5269"
  tokyo-light-ansi-bright-black: "#6B7089"
  tokyo-dark-foreground: "#C0CAF5"
  gruvbox-light-foreground: "#3C3836"
  gruvbox-dark-foreground: "#EBDBB2"
  one-light-foreground: "#383A42"
  one-dark-foreground: "#DCDFE4"
  solarized-light-foreground: "#586E75"
  solarized-dark-foreground: "#93A1A1"
  kanagawa-light-foreground: "#545464"
  kanagawa-dark-foreground: "#DCD7BA"
  rose-pine-light-foreground: "#575279"
  rose-pine-dark-foreground: "#E0DEF4"
  dracula-companion-background: "#F4F3F7"
  dracula-companion-foreground: "#514761"
  dracula-dark-foreground: "#F8F8F2"
  nord-light-foreground: "#2E3440"
  nord-dark-foreground: "#D8DEE9"
  vesper-companion-background: "#FAF8F5"
  vesper-companion-foreground: "#504B44"
  vesper-dark-foreground: "#FFFFFF"
  accent-blue-light: "#2463EB"
  accent-blue-dark: "#82AAFF"
  accent-graphite-light: "#494A50"
  accent-graphite-dark: "#A6ADC8"
  accent-green-light: "#159570"
  accent-green-dark: "#8BD5A2"
  accent-cyan-light: "#1D85C0"
  accent-cyan-dark: "#7DC4E4"
  accent-purple-light: "#6956A6"
  accent-purple-dark: "#C6A0F6"
  accent-amber-light: "#B08009"
  accent-amber-dark: "#EED49F"
  accent-pink-light: "#D5537F"
  accent-pink-dark: "#F5BDE6"
  accent-red-light: "#CC3A52"
  accent-red-dark: "#ED8796"
  accent-orange-light: "#DF5619"
  accent-orange-dark: "#F5A97F"
  success-light: "#287B48"
  success-dark: "#A6E3A1"
  warning-light: "#986500"
  warning-dark: "#F9E2AF"
  failure-light: "#C43B4B"
  failure-dark: "#F38BA8"
typography:
  tab:
    fontFamily: "macOS system font"
    fontSize: "12pt"
    fontWeight: 400
  tab-selected:
    fontFamily: "macOS system font"
    fontSize: "12pt"
    fontWeight: 600
  space:
    fontFamily: "macOS system font"
    fontSize: "13pt"
    fontWeight: 400
  space-selected:
    fontFamily: "macOS system font"
    fontSize: "13pt"
    fontWeight: 500
  agent:
    fontFamily: "macOS system font"
    fontSize: "13pt"
  metadata:
    fontFamily: "macOS system font"
    fontSize: "11pt"
  section-label:
    fontFamily: "macOS system font"
    fontSize: "11pt"
    fontWeight: 600
  pane-title:
    fontFamily: "macOS system monospaced font"
    fontSize: "11pt"
    fontWeight: 400
  pane-title-focused:
    fontFamily: "macOS system monospaced font"
    fontSize: "11pt"
    fontWeight: 600
  pane-context:
    fontFamily: "macOS system monospaced font"
    fontSize: "11pt"
  settings-body:
    fontFamily: "macOS system font"
    fontSize: "13pt"
  search-input:
    fontFamily: "macOS system font"
    fontSize: "14pt"
  search-context:
    fontFamily: "macOS system font"
    fontSize: "10.5pt"
  terminal:
    fontFamily: "Maple Mono CN, SF Mono"
    fontSize: "13.5pt"
rounded:
  tab: "5pt"
  search-selection: "6pt"
  device-switcher: "6pt"
  sidebar-selection: "8pt"
  agent-selection: "7pt"
  font-preview: "7pt"
  reconnect: "8pt"
  pane: "System-concentric outer bottom corners; internal and full-screen corners 0pt"
spacing:
  sidebar-row-x: "8pt"
  sidebar-content-indent: "18pt"
  space-row-y: "6.5pt"
  agent-row-y: "9.5pt"
  sidebar-inset: "10pt"
  row-line-gap: "2pt"
  list-gap: "2pt"
  content-inset: "12pt"
  toolbar-inset: "16pt"
  creation-inset: "24pt"
  canvas-top-clearance: "3pt"
  canvas-edge-inset: "3pt"
  pane-split-gap: "6pt"
  tab-strip-inset-x: "8pt"
  tab-strip-inset-y: "3pt"
  tab-gap: "4pt"
  pane-outline-top: "7pt"
  terminal-content-inset: "4pt"
  appearance-row-gap: "7pt"
  appearance-inner-gap: "4pt"
  appearance-inset-x: "25pt"
  settings-inset-top: "20pt"
  appearance-inset-bottom: "16pt"
  notifications-inset: "24pt"
components:
  integrated-bar:
    height: "28pt"
  sidebar:
    width: "260pt"
  sidebar-actions:
    height: "40pt"
  sidebar-footer:
    height: "40pt"
  sidebar-group:
    typography: "{typography.section-label}"
    height: "28pt"
  space-row:
    typography: "{typography.space}"
    rounded: "{rounded.sidebar-selection}"
    padding: "6.5pt 8pt"
  agent-row:
    typography: "{typography.agent}"
    rounded: "{rounded.agent-selection}"
    padding: "9.5pt 8pt"
  tab:
    typography: "{typography.tab}"
    rounded: "{rounded.tab}"
    height: "22pt"
  tab-selected:
    typography: "{typography.tab-selected}"
    rounded: "{rounded.tab}"
    height: "22pt"
  pane-title:
    typography: "{typography.pane-title}"
    height: "14pt"
  pane-title-focused:
    typography: "{typography.pane-title-focused}"
    height: "14pt"
  pane-close:
    width: "22pt"
    height: "22pt"
    symbolSize: "9pt"
  pane-restore:
    width: "22pt"
    height: "22pt"
    symbolSize: "10pt"
  terminal-content:
    headerHeight: "24pt"
    horizontalOverhead: "8pt"
    verticalOverhead: "28pt"
  device-switcher:
    height: "28pt"
    rounded: "{rounded.device-switcher}"
    padding: "0pt 8pt"
  device-popover:
    width: "270pt"
    padding: "6pt"
  search:
    width: "440pt"
    padding: "0pt 12pt"
  search-input:
    typography: "{typography.search-input}"
    height: "22pt"
  search-header:
    height: "44pt"
  search-result:
    height: "36pt"
    rounded: "{rounded.search-selection}"
    padding: "0pt 10pt"
  search-footer:
    height: "28pt"
  settings-appearance:
    width: "420pt"
    height: "190pt"
  settings-terminal:
    width: "420pt"
    height: "410pt"
  settings-connections:
    width: "600pt"
    height: "480pt"
  settings-notifications:
    width: "420pt"
    height: "220pt"
  settings-tailcat:
    width: "600pt"
    height: "480pt"
  settings-about:
    width: "420pt"
    height: "410pt"
  preference-menu:
    typography: "{typography.settings-body}"
    height: "24pt"
  appearance-mode:
    minWidth: "150pt"
  terminal-weight:
    minWidth: "150pt"
  appearance-palette:
    width: "120pt"
    height: "24pt"
  accent-swatch:
    size: "16pt"
    padding: "3pt"
  appearance-language:
    width: "100pt"
    height: "24pt"
  space-creation-sheet:
    width: "480pt"
    padding: "{spacing.creation-inset}"
  reconnect:
    rounded: "{rounded.reconnect}"
    padding: "{spacing.content-inset}"
---

# Design System: HerdrX

## Overview

**Creative North Star: "Native workbench"**

HerdrX follows the compact ACCM reference: a palette-colored native workbench where Spaces and Agent tasks lead directly to real terminal content. The sidebar, tab strip and terminal ground belong to the same theme; outlined Space selection, stronger Agent selection and readable execution states make the working context clear.

SwiftUI and AppKit provide system type, controls and keyboard behavior; Ghostty provides the terminal canvas. Preserve the HerdrX name and original purple diagonal slash icon. The artwork and native packaging provenance remain in [Resources/Icon/README.md](Resources/Icon/README.md) and [Resources/Icon/Prompt.txt](Resources/Icon/Prompt.txt). This iteration adds no shipping raster assets.

**Key Characteristics:**

- Compact Space navigation and a single integrated tab strip around the terminal canvas.
- Switchable palette families with independent appearance and accent preferences.
- Two-line Space and Agent rows with aligned text and visible trailing state.
- Six native settings toolbar tabs and a two-line device chooser.

The current authority is [PRODUCT.md](PRODUCT.md), [ACCM DIRECTION.md](docs/accm-fidelity/DIRECTION.md) and the [workbench surface brief](.impeccable/surfaces/app-workbench-swift.md). This replaces the earlier neutral grey direction. Independent local Shells and their list/create entry points are removed; Space-owned ordinary sessions, Agents, tabs and splits remain. Earlier removals of the Agent launcher, file tree, previews, transfer and attachment delivery still apply.

Tokens are source-observed native points and color seeds from `App/Theme.swift`, `ThemeColors.swift`, the pinned GhosttyTheme definitions, `Workbench.swift`, `Sidebar.swift`, `Tabs.swift`, `Terminal.swift`, `Preferences.swift`, `PreferenceMenu.swift`, `DeviceSwitcher.swift`, `SearchInput.swift` and `WindowBehavior.swift`. Foreground, accent and state seeds undergo the contrast derivation below; they are not unconditional rendered values. The JSON sidecar records these derivations, state rules and native behavior that do not fit the frontmatter schema. It does not provide HTML/CSS replicas of native controls.

The current [theme validation](docs/theme-correction/VALIDATION.md) records all ten families in light/dark, Default, Follow Herdr, all nine accent captures, hidden-pane restoration, reattach continuity and 3,600 computed semantic text/surface pairs. The [updater validation](docs/app-updates/VALIDATION.md) records signed fixture installation, relaunch, automatic download/install on quit, cancellation and signed-feed rejection. Earlier [native checks](docs/accm-fidelity/evidence/native-checks.json) and [Space RPC checks](docs/accm-fidelity/evidence/space-actions-rpc.json) remain historical evidence for navigation geometry and actions. Fixtures contain synthetic names and illustrative output over real PTY/attach/RPC. The documenter read source/evidence and opened representative supplied captures, without operating the app. Reviewer verdicts govern acceptance. OS-driven System appearance changes, arbitrary terminal color pairs, live SSH/Tailcat, notification delivery, VoiceOver, IME, English updater layout and older macOS remain outside the completed evidence. These local changes are not a published release.

The current UI polish updates these source-observed geometry and settings rules. Its [settings review](docs/ui-polish/SETTINGS.md) records the completed source and offscreen native-control checks. Fresh running-app visual acceptance is **not complete**: computer-use access was denied, and remained denied after the user gave written authorization. Earlier theme/updater screenshots remain historical evidence for their respective passes; they do not accept this new geometry. No ship or release claim is made.

## Colors

The selected family supplies the shared terminal/workbench ground. Explicit per-family navigation text roles keep ordinary labels restrained; independent accents identify selection and focus. Terminal ANSI colors remain a separate set of roles.

### Primary

- **Blue, Graphite, Green, Cyan, Purple, Amber, Pink, Red and Orange:** the paired light/dark frontmatter tokens are explicit app-defined seeds. `Theme.accentStroke` retains the chosen hue; `Theme.accentText` adjusts only text contrast. Washes, wash borders and on-accent text have separate roles. Follow Theme chooses Amber for Gruvbox/Vesper, Pink for Rosé Pine, Purple for Dracula, Cyan for Nord and Blue for the remaining families.
- **Space selection:** accent wash at 0.10 light / 0.14 dark with a one-point outline at 0.24. **Agent selection:** stronger wash at 0.14 light / 0.19 dark without a visible outline. Hover mixes theme foreground at 0.04.
- **Tabs:** inactive fill mixes chrome with foreground at 0.08 light / 0.10 dark; hover uses 0.12 / 0.14. Selection mixes the inactive fill with accent at 0.16 light / 0.22 dark. Every tab has a one-point outline: neutral foreground at 0.12 (0.18 on hover), accent at 0.40 when selected and 0.75 while dragging. Inactive labels/counts use a separate role checked against both inactive fills at 4.5:1. Search uses the ordinary selection wash. Active pane outlines use raw accent stroke and their semibold main titles use readable accent text while the window is key; inactive titles use theme secondary.

### Secondary

- **Success green:** completed Agent state words and connected-device dots. Idle/unknown states use neutral secondary. State colors are checked on normal or selected surfaces according to their actual use.
- **Warning amber:** blocked/waiting-input state words and glyphs. **Failure red:** offline-device dots. Working and unread use stable blue independent of the user's accent. Readable text and different glyph shapes accompany these colors.

### Neutral

- **Catppuccin ground and text:** HerdrX Default currently resolves to Latte/Mocha, as does the explicit Catppuccin family. The prior white/grey default tokens are obsolete.
- **Semantic text and palette-derived chrome:** `Theme.content` uses the selected definition's background. Catppuccin uses explicit Latte mantle / Mocha crust chrome and distinct secondary/decoration seeds. Other families blend chrome by 0.045 light / 0.06 dark and secondary by 0.28 toward the background. Normal foreground, secondary, accent text and state roles target 4.5:1 against canvas, chrome and hover; selected text/state roles are checked separately against selected washes. Normal text and state colors do not change with accent. Unfocused pane borders use foreground at 0.28; focus changes only the color to the theme accent. Native settings controls retain platform text and rendering.
- **Tokyo Day slate:** HerdrX adapts the upstream blue default to the `tokyo-light-foreground` token for terminal default, cursor, selection foreground and ANSI 0, with `tokyo-light-ansi-bright-black` for ANSI 8. Cursor text uses the background. This is an authored adaptation, not an incorrectly copied upstream definition.
- **Gruvbox Light and Rosé Pine Dawn:** the named HerdrX light definitions set ANSI 0 to each upstream default foreground so black text remains dark on pale diff fills.
- **Dracula and Vesper light companions:** the frontmatter holds HerdrX-authored ground/text pairs. Source ANSI brightness is capped at 0.55, selection uses the source-defined companion color, and cursor follows foreground. These companions are not upstream official light variants.

| Family | Light / dark definition | Follow Theme accent |
| --- | --- | --- |
| HerdrX Default / Catppuccin | Catppuccin Latte / Mocha | Blue |
| Tokyo Night | HerdrX Day adaptation / Night | Blue |
| Gruvbox | HerdrX Light ANSI-0 adaptation / Dark | Amber |
| One | One Half Light / Dark | Blue |
| Solarized | iTerm2 Solarized Light / Dark | Blue |
| Kanagawa | Lotus / Wave | Blue |
| Rosé Pine | HerdrX Dawn ANSI-0 adaptation / Rosé Pine | Pink |
| Dracula | HerdrX Dracula Light / Dracula | Purple |
| Nord | Nord Light / Nord | Cyan |
| Vesper | HerdrX Vesper Light / Vesper | Amber |

Pinned Ghostty definitions remain the source for each palette, with the named HerdrX adaptations above. ANSI slots retain their authored values without a foreground-only contrast adjustment, since the same slot may serve as a background or reversed color. Ghostty minimum contrast is 1, faint opacity is 0.65, and cursor text is mapped when supplied. Explicit indexed colors, RGB output and arbitrary foreground/background pairs retain application meaning and are not universally contrast-certified.

Local Herdr theme reads local `~/.config/herdr/config.toml` `[theme].name`, resolves a supported family and falls back to Catppuccin for absent/unrecognized names. It does not edit Herdr configuration or synchronize remote/custom palette values. System/Light/Dark controls appearance independently from family and accent. System selection and the native callback are evidenced; a macOS-driven appearance transition was not exercised.

**The Theme Continuity Rule.** Apply the selected family to chrome and terminal together, preserve independent appearance/accent preferences, and keep existing sessions mounted when colors change.

**The State Meaning Rule.** Keep selection, pane focus, Agent execution and device connection as distinct signals, with state text and glyphs alongside color.

**The Text Role Rule.** Use semantic app roles for navigation and status, keep raw selection hue separate from readable accent text, and do not recolor arbitrary terminal output to claim universal contrast.

## Typography

Use native macOS system type for navigation and settings, and system monospaced type for pane titles/context. The frontmatter records the explicit hierarchy; no custom display type is used. Space and Agent names have the same size. Space selection becomes medium, selected tabs become semibold, and focused pane titles become semibold. Metadata and group headings remain smaller than task names.

Space rows carry title plus branch/directory; Agent rows carry task plus status glyph, then tool/Space/device context plus a 64pt trailing state column. Unread uses a short localized label; full status stays in help and the accessible value. Both stay two lines. Long labels truncate before displacing status; help retains full identity and supplied runtime details. Agent metadata is never fabricated to fill a row. Pane main titles truncate at the tail, secondary context in the middle.

Git branch lookup is optional sidebar metadata. While loading or when lookup fails (including missing Git on a remote host), keep the neutral folder icon and “Directory” label. If a previously read branch exists, retain its name without an inline stale warning. Put refresh failure context and diagnostics in the row's help; do not imply the directory or Herdr session is unusable. Connection health remains in the device header. See [sidebar metadata validation](docs/sidebar-metadata/VALIDATION.md).

Terminal font defaults to Maple Mono CN when installed, otherwise SF Mono, using the frontmatter terminal size. Existing selected fonts and sizes remain intact. Size spans 9–22pt in 0.5pt steps; line spacing spans 100–140% in 5% steps, with 100% as the default. The visible SF Mono weight control offers Light, Regular and Medium; a saved legacy Semibold/Bold value appears as an additional selected segment until the user chooses a current weight, keeping the control and preview consistent. Other families disable this control. Thin strokes and copy-on-select default on; mouse reporting defaults off. Restore Defaults returns those settings and Regular weight. Import from Ghostty reads font-family/font-size from a selected file; it is not a continuous settings sync. The preview uses the selected font with Chinese, ASCII and digits.

**The Reading Rule.** Keep compact native navigation type, preserve user terminal preferences, and retain full context in help when labels truncate.

## Layout

Measurements are macOS points. The original workbench reference is 3840 × 2100 pixels at 2× Retina; use original pixels divided by two when comparing it. A viewer's resized preview is not a 1× source. `WindowBehavior` enforces a 980 × 620 minimum outer window. The titlebar is hidden with a 78pt traffic-light reserve. The detail region contains the integrated tab bar, divider, top canvas clearance and real terminal panes.

The sidebar uses the default width token only when no saved width exists, persists width/visibility, and resizes from 200 to 480pt. Double-click restores the same default without a migration that overwrites existing widths. A one-point separator has a seven-point drag target; keyboard adjustment uses 20pt increments. New Space/options/Search remain above the scrollable groups; Device Filter and Settings remain in the footer. Device groups pin and collapse persistently; the Agent group is omitted when empty. There are no independent Shell or Terminals groups.

Space and Agent text starts approximately 36pt from the window's left edge: sidebar inset + row padding + content indent. Two native text lines, their shared line gap and distinct vertical padding produce approximately 45pt Space and 51pt Agent fills. These are rendered targets, not additional fixed-height constraints. Device connection dots follow the device name. State words reserve their own width at the Agent row's trailing edge.

Tabs reserve semibold title width in both selection states, 18pt side padding and, for multiple panes, a separate 10pt monospaced-digit count with an 8pt gap; total width is clamped to 40–200pt, inside a shared 28pt integrated bar. Each pill is 22pt high with 3pt above/below, 8pt leading inset and 4pt gaps. Inactive, hovered and selected fills follow the stronger color roles above, with visible one-point outlines in every state. Overflow scrolls horizontally; selection reveals the active tab. Each pane owns a separate 1pt inside outline, with 3pt outer whitespace on every side. The canvas contributes the outside 3pt and neighboring frames each contribute 3pt at internal boundaries. The top outline lies 7pt below its frame top, so adjacent border gaps are 6pt horizontally and 13pt vertically. The first outline is 39pt below the window top (28pt bar + 1pt divider + 3pt margin + 7pt title offset).

`PaneMetrics` owns the 4pt terminal content inset, 24pt header, 8pt horizontal overhead and 28pt vertical overhead. Terminal views use these same values as `Desk.minimumPaneSize` and split eligibility, keeping the space reserved for chrome consistent with the intended minimum of 24 columns and six rows. The minimum pane is `max(160, font × 0.65 × 24 + 8)` by `max(100, font × 1.5 × 6 + 28)` points, with a 13.5pt fallback font. Split handles are seven points wide; keyboard/accessibility adjustment moves five percentage points within those minimum bounds.

Settings uses six native toolbar icon tabs. Frontmatter dimensions describe each selected tab's content frame, excluding the OS toolbar/titlebar. Appearance's labels are 48pt wide with a 10pt gap after the horizontal inset, placing controls at about 83pt. The row gap and inner helper/accent gap use their frontmatter tokens. The accent row contains nine circles plus Follow Theme, with a reserved selection checkmark. When their intrinsic widths exceed the content column, Follow Theme moves below the swatches with the existing 4pt inner gap. Appearance and Terminal scroll vertically when content grows; Appearance adds a 16pt bottom inset. Appearance mode and Terminal weight segments retain a 150pt minimum width and may grow to fit localized labels. Terminal settings uses a native grid, aligned font/size/weight/spacing fields, checkbox explanations, import/reset actions and a preview. Notifications fills the available width with a consistent 24pt leading inset. Connections and Tailcat use the wider frame; scrollable forms may extend below the viewport.

The device popover offers All Devices, two-line identity/source rows, connection dots, a current-selection checkmark and Add Device. Its device list is capped at `min(360, deviceCount × 46)`pt. Search uses the frontmatter width and header/result/footer dimensions; the results region is `min(320, max(44, resultCount × 36))`pt. New Space remains a compact named-directory sheet.

**The Terminal Space Rule.** Keep the main detail area available to real Space-owned terminal panes and keep supporting navigation compact.

## Elevation & Depth

There is no authored shadow or motion vocabulary. Theme surfaces, thin outlines, selection fills and pane-title cutouts convey structure. Native popovers, sheets, alerts, controls and grouped forms retain platform depth and focus treatment. The recovery overlay uses `.regularMaterial`. A settings group is not a decorative card pattern for the workbench. Capture badges and cursor highlights are tooling overlays, not product design elements.

## Shapes

Use the component-specific frontmatter radii for rows, tabs, preview, search and recovery. Only the bottom corners nearest the window contour use continuous, concentric curves. Resolve their radii from public SwiftUI window geometry after the 3pt canvas inset (resolved radii on macOS 27+, container corner insets on macOS 26; nominal 10pt window radius minus the inset on older systems). The left corner stays square beside a visible sidebar. Every internal split corner, top corner and full-screen corner stays square. Subtract half the stroke width for the outline centerline and 4pt for the terminal content mask; both use the same continuous path. Recompute after sidebar, layout, backing-scale and full-screen changes. Strokes are 1pt at both 1× and Retina, including while focused, with both edges aligned to backing pixels. Each outline is inset by half the stroke width. Internal edges are independent, not overdrawn shared lines. Accent controls retain their native circular geometry.

## Components

### Workbench actions and navigation

Compact borderless native buttons use SF Symbols with localized labels/help. New Space offers quick creation and a named-directory option. The tab plus creates a terminal tab within the selected Space; Pane Layout contains right/down splits and zoom/restore with capability-aware disabled states. Sidebar content comprises device Spaces and automatically detected Agents. Search also reaches the ordinary terminals within Spaces. The empty canvas says Choose a Space and offers New Space. Agent launch and independent Shell entry points do not return.

### Agent rows and device status

Agent rows prefer task labels, server task titles, tab labels and session names, with directory/Untitled Task fallback instead of repeating a tool brand. Context combines the tool icon, Space and device when multiple devices are visible; tool text remains in help and accessibility. Use the snapshot agents array as authoritative, falling back to pane detection only when that array is absent. Keep the Agents group and a short server-reported empty state visible when empty. Working uses a half-filled circle; blocked/unread uses a filled circle; other states use an outline. State text carries the semantic color rules above. Codex, Claude, Cursor, Gemini, Grok, Kimi, OpenCode, Pi/Oh My Pi and Copilot use native SF Symbol pictograms; these are not vendor logos. Device status is separate: green when connected, neutral while connecting or when local Herdr is stopped, and warning for connection failures. Accessible status text and adjacent recovery actions carry the meaning. A failed connection can retain a clearly marked cached snapshot.

### Tabs, pane titles and splitters

AppKit tabs combine native type, natural widths, accent selection and neutral theme hover. `TabMetrics` shares bar height, tab height, strip inset, gap and radius with the SwiftUI host. After 4pt of horizontal movement, the complete pill follows the pointer without vertical drift, with a stronger outline and small shadow. Neighbours make room with 180ms ease-out motion; a dashed pill shows the destination. Release animates into that slot and uses the existing queued `tab.move` action. Stable button identity supports both reorder and failure rollback. Escape, window deactivation, scope/order changes, source removal or loss of write access cancel the preview. Edge scrolling runs at 60Hz in a 28pt edge zone. Reduce Motion removes interpolation. Tabs expose radio-button selection in their current order and pane-count help. Pane counts are grouped once per tab-list evaluation. See [tab interaction validation](docs/tab-interaction/VALIDATION.md) for current evidence and limits.

Pane titles sit in a background-colored top-border cutout. The cutout begins nine points inside the pane frame, has five points of masking on either side and five points between main/context runs; both use 11pt monospaced text. Below 260pt of available title width, omit secondary context and prioritize the main title; otherwise main text receives at most 64% when context exists. Recognizable shell cwd titles show a directory basename, while authored labels and arbitrary task titles stay intact. Single-device workspaces omit repeated device context; complete original identity remains in help/accessibility and search. Focused panes use accent outlines/titles; inactive panes use foreground at 28% and secondary title text. Every row uses the same top-border title cutout. PaneMetrics applies half of the 6pt gutter to each adjacent frame; terminal content, titles, hover and close controls all use that frame. The 7pt resize target spans the gutter and shows a 1pt accent line while dragging, and split minimums include the largest gutter inset. Close stays at 50% opacity for the focused pane and 100% during pane/button hover or VoiceOver. Visibility changes ease out over 150ms (immediate under Reduce Motion); invisible buttons do not hit-test or expose an accessibility element. The backing remains opaque during fades. Header context menus target the clicked pane and omit terminal copy/paste/link actions, and ⌘⇧W invokes the existing Close Pane action; zoom exposes Restore. Both use 22pt native button targets, with a 9pt semibold close symbol and a 10pt medium restore symbol. Hover/pressed fills use theme foreground at 0.07/0.14 with a 4pt corner radius inside a 2pt inset, and the controls retain native focus treatment. Full title/context remains attached to the terminal's help and accessibility label. Native splitters expose values, bounds and keyboard/accessibility adjustment.

Ghostty surfaces remain mounted as workspaces are hidden. Layout and explicit focus requests are separate, and hidden views are not assigned visible frames. Ordinary attachments never request takeover. When control ends or is refused, a supported Herdr terminal-session observer streams read-only frames into the existing surface. Reconnect retries ordinary control; Take Control is a separate confirmed action. Observer viewport changes do not resize the server PTY. Returning from a detected Agent to a verified foreground shell clears local stale Kitty, modifyOtherKeys and focus-reporting modes without changing screen, scrollback or bracketed paste. A live Herdr attachment retains its transport mouse modes so wheel input continues to reach server history; full mouse-mode cleanup happens when the attachment ends or restarts. Explicit interrupt sends Ctrl-C only, then verifies the foreground before restoring modes; it never injects a shell command. Removing independent Shell support does not remove Space-owned PTYs or terminal settings.

Physical Ctrl-C in a writable terminal sends a single ETX per press and consumes the matching C and Control releases, including when Control is released first. Repeated presses remain available during foreground verification. Other modifier combinations and marked-text input retain native handling. Keyboard-mode negotiation on a fresh or reconnected attachment also triggers the existing foreground-shell verification, independent of Agent metadata. Only a verified shell permits local keyboard recovery; live attachment mouse modes remain intact. See [input recovery validation](docs/terminal-input/VALIDATION.md).

Attached wheel events also verify the actual foreground process. Idle shells use Herdr's history scroll API, preventing stale TUI mouse modes from injecting report text at the prompt. Running programs keep native wheel reporting. Per-terminal serialization, fractional trackpad accumulation and attachment identity checks preserve direction and reject stale events; observers and verification failures never forward a wheel. See [scrolling validation](docs/terminal-scrolling/VALIDATION.md), including the distinction between a reproduced stale-mode leak and residual output after forcibly terminating Codex.

### Search and forms

Search uses a borderless native AppKit field, stable result identities, two-line context and shared hover/keyboard selection. Arrow keys select, Return opens and Escape cancels; marked text is respected by the source implementation. New Space captures the intended device/name/directory through submission, shows validation/error/busy state and restores focus appropriately on cancel. Object context menus and destructive confirmations identify the affected Space, Tab or Pane.

### Settings

The six top-level tabs are Appearance, Terminal, Connections, Notifications, Tailcat and About. Connections contains Devices and Advanced: Plugins. Appearance separates mode, palette, accent and language. `PreferenceMenu` uses an actual `NSPopUpButton`; the palette menu contains twelve choices and a separator after Default/Local Herdr theme. Choices carry stable setting IDs in `NSMenuItem.representedObject`, keeping identity independent from translated or duplicate display names. Updates compare IDs, titles and separator structure; an unchanged menu retains its native item instances. Native keyboard, focus, disabled and popup behavior remain intact.

Terminal preferences and its actual-font preview follow Typography; scrolling keeps the maximum-size preview and import errors reachable. Saved device names truncate in the middle before displacing actions, with full identity retained in help. Notifications has a dedicated native page; Tailcat has its own identity/connection page. About uses the 420×410pt content frame for version/project, updates and notices. Native controls present automatic checks, optional automatic download/install, status, last check, failure details, manual update action and release notes. A spinner appears only for a pending manual check; canceled checks/downloads clear progress and leave retry available. Status copy distinguishes a downloaded/verified update from one ready to install on quit. Descriptions align with the trailing-switch labels without checkbox indentation and wrap vertically. Immutable bundled notices are read once, while their localized fallback remains language-aware.

One app-lifetime Sparkle updater serves both the application-menu Check for Updates action and About. Automatic checks default on at a 24-hour interval while the app runs; automatic downloads default off and persist after opt-in. Both Homebrew and direct installations use this flow. Background downloads install on quit; Herdr-owned sessions continue independently. Development builds disable updates unless the isolated fixture environment enables them. The release pipeline requires signed feed and archive verification; this is separate from Apple Developer ID signing/notarization and does not mean these changes have been published. See [updater validation](docs/app-updates/VALIDATION.md) for runtime proof and remaining limits.

## Do's and Don'ts

### Do:

- Do retain HerdrX identity, original icon provenance and native SwiftUI/AppKit/Ghostty rendering.
- Do follow the ACCM reference's compact spacing using original Retina pixels and native points.
- Do keep ten theme families plus Default/Local Herdr theme, with appearance and accent independent.
- Do preserve saved sidebar width, terminal preferences, Space sessions, Agent navigation, tabs and splits.
- Do distinguish Space selection, Agent selection, pane focus, execution status and device connectivity.
- Do derive app text and state colors against the authored surfaces while preserving independent palette and accent choices.
- Do keep automatic installation opt-in, expose manual update access and report canceled or failed updates as retryable.
- Do keep source facts, synthetic fixture content, screenshots and completed runtime checks separate.

### Don't:

- Don't restore independent local Shells, their lists/create entries, Agent launching, file trees, previews, transfer or attachments.
- Don't freeze the app to one screenshot palette or present HerdrX light companions as upstream official themes.
- Don't replace native controls or real terminals with web styling, raster mockups or simulated terminals.
- Don't restore a second fixed toolbar or persistent bottom status bar.
- Don't add decorative shadows, oversized branding or card containers around terminal panes.
- Don't substitute terminal ANSI foreground for every app label or use secondary text as a global control tint.
- Don't claim universal terminal contrast, an OS-driven appearance-transition pass, production Agent activity, external-service acceptance or a published release from this evidence.

### Agent identity and sidebar scrolling (2026-10-10 follow-up)

Agent metadata uses a 12pt brand vector with a 4pt text gap; search uses the same component at 14pt. Resources resolve color first (`.original`), monochrome second (`.template`), then the terminal SF Symbol. The pinned LobeHub source offers color for Claude, Codex, Gemini, DeepSeek, Kimi and Antigravity. Cursor, Grok, Copilot, OpenCode and Pi retain upstream monochrome marks. SVG dimensions and compact arc flags are normalized for CoreSVG without changing geometry or colors. Kimi has a black backing for its white mark. Source URLs and adapted hashes are in `Resources/Icon/AgentIcons.json`; the MIT license remains bundled.

The sidebar's own native scroll view uses overlay scrollers, small control size and automatic hiding, avoiding the legacy reserved gutter. This is scoped to sidebar content and does not change global macOS preferences. New icons and scroller behavior compile, but running-app visual acceptance will be performed by the user after the requested local update.


### Object rename and Herdr ownership

Double-click, the Tab context menu and Terminal → Rename Tab… (⌘⌥R) open a 400pt sheet with focused, selected text. Space and Pane rename use the same sheet. Blank/unchanged or invalid multiline names cannot submit; Enter saves, Esc cancels, and marked-text commands remain with the IME. A serial queue wraps the existing Herdr workspace.rename/tab.rename/pane.rename RPC and snapshot refresh. Captured device, endpoint, object and parent IDs define the target; navigation or a moved/deleted target cannot redirect the request. Failures retain the entered value and original server-backed label, with inline retry. There is no parallel naming/session model. Current validation: [adversarial UI review](docs/adversarial-ui-review/VALIDATION.md); earlier Tab evidence remains in docs/ui-five/VALIDATION.md.

### Connection recovery

A missing or refused local socket is an expected stopped-session state, identified by its POSIX error code. Show a short status such as “Herdr is not running” and Start Herdr. Put guidance, paths and raw diagnostics behind the accessible info button in a selectable Connection Details popover. Connecting and Starting Herdr use a small native progress indicator. Background retries keep the last useful explanation stable, with no static countdown or repeated status flashing. Reuse the same recovery view in the sidebar, empty canvas and Connections settings, with wrapping actions at the 200pt sidebar minimum. Center the empty-canvas status, device name and actions as one group; constrain long device names to two lines with full identity in help. Existing terminal surfaces and cached snapshots stay mounted and are marked offline.

Start Herdr invokes the installed Herdr CLI only after a user action, for the captured default or valid named local session. It does not guess custom socket mappings, launch remote services, install a daemon manager or stop a server when the GUI quits. A valid server snapshot confirms readiness. Duplicate starts are suppressed; editing/removing a connection invalidates its pending UI result. Failure retains an actionable explanation and diagnostic details; a missing CLI links to Herdr installation. Custom paths lead to Connections settings, and SSH authentication errors ask the user to authenticate in Terminal. English and Simplified Chinese use the same state model. Verification is recorded in `docs/connection-recovery/VALIDATION.md`.

### Tab scroll containment

The 28pt tab bar scrolls horizontally only. Its document height tracks the viewport; 22pt pills stay centered with 3pt vertical insets. Ordinary vertical wheel input is ignored. Horizontal, diagonal and Shift-wheel input, selection reveals, edge dragging and window resize all retain a zero vertical offset. Both elastic axes are disabled and horizontal offsets are clamped to the actual overflow. Regression coverage compiles the production AppKit view directly in `scripts/test-tabs.sh`.


### Adversarial interaction review — 2026-10-11

The [review](docs/adversarial-ui-review/REVIEW.md) records source-backed findings and remaining native acceptance. Context menus separate object, ordering and destructive actions. Single objects omit redundant moves/zoom; connected devices omit Retry. Clipboard actions require usable text/selection and stay in terminal content. Close buttons share the clicked pane's busy/connection eligibility.

Split availability uses the clicked pane's unzoomed layout slot and current canvas dimensions; invoking it does not first navigate to that pane. On success, restore the normal layout and focus the new pane only if the user's original focus/navigation is unchanged. Both window activation transitions redraw pane focus treatment. Tab selection reserves the same text width in either weight.

Herdr snapshot rectangles share their area's absolute cell-coordinate origin. Subtract that origin before scaling them into the GUI canvas; server-side sidebar/header offsets must not displace native panes. Preserve the server's split proportions and chrome insets. The [layout-origin compatibility record](docs/pane-spacing/layout-origin.md) covers old/new Herdr snapshots and the physical-device verification boundary.

Object rename hands marked-text commands to the IME; its compact sheet contains the name, optional failure and actions without generic character-format guidance. Connections discovery labels stay short and can stack. Add Device uses one action for mouse/keyboard/accessibility routing to a fresh Connections → Devices form, even if Settings previously showed Plugins or an existing edit. Ordinary Settings navigation retains its state. Removing the filtered device resets the filter. Font import failures are localized and name the file without printing its full path.

These contracts do not establish a fresh rendered or live-IME pass. The [validation record](docs/adversarial-ui-review/VALIDATION.md) separates local checks, macOS CI and outstanding native scenarios. No new raster assets, Herdr protocol, release or preference migration.


The completed follow-up gives tab pane counts their own trailing text slot, with native button/focus semantics retained. Connections discovery/import shows inline progress, actual added counts, empty results and errors; only one discovery runs at a time, with cancellation and no late import after cancellation. Tailcat Edit routes from Connections to the requested device and rejects a removed target before saving. Workspace groups focus/resize/numbered-tab actions in submenus, Terminal owns repair, and existing shortcuts remain unchanged. Close confirmations name their action and plainly describe the running processes that stop. All 20 review items have source changes; live macOS acceptance remains a separate gate.

### Selection and color roles — 0.1.13

The [selection and theme validation](docs/selection-theme/VALIDATION.md) supersedes the earlier global contrast contract. Normal foreground/secondary/decoration are accent-independent. Selected text is checked on its own washes; accent stroke keeps the chosen hue, accent text is contrast-adjusted only for normal surfaces, and accent wash/border/on-accent have separate roles. Catppuccin chrome uses Latte mantle / Mocha crust; terminal backgrounds retain their established palette values. Working/unread use stable blue, done uses success, idle/unknown use neutral text. All statuses retain shapes and labels.

A captured left press waits for click versus a 4pt drag. Local gestures temporarily use Ghostty's supported reporting toggle, preserving actual modifiers without a synthetic Shift anchor. The engine's copy-on-select is off; the host commits a nonempty completed local selection once through copy_to_clipboard:plain. Selection clears on copy; a verified pasteboard write shows one noninteractive “Copied” label and an accessibility announcement. Cancellation releases the engine and restores reporting without copying. The upper/lower 12pt map to out-of-bounds coordinates for Ghostty's own selection-scroll timer.

Terminal ANSI slots keep authored palette values (including the existing named light companions/black fixes), minimum contrast remains 1, faint opacity is 0.65. No generic RGB/indexed stream transformation is introduced. This preserves background/reverse/diff semantics; it does not guarantee arbitrary TUI contrast. Local Herdr theme means local family mapping only.

### Pane wheel routing (0.1.15)

Wheel input reaches the attached Herdr session independently of the click-reporting preference. The host temporarily enables reporting for the wheel only, refreshes its position without emitting hover reports, and preserves native precision, direction and momentum. Ghostty encodes the protocol and accumulates small deltas; Herdr chooses server history, TUI mouse input or alternate-screen scrolling. Local text drags retain their existing selection behavior. Read-only observation accepts no wheel input: Herdr 0.9.3 exposes live frames without a private observer history viewport. Its recovery banner states this limit and offers the existing Reconnect / confirmed Take Control actions. See [scroll validation](docs/terminal-scrolling/VALIDATION.md).


## Herdr integration additions (2026-10-12)

Connections exposes “Follow Herdr machine directory” and marks managed devices. The enabled toggle makes Herdr the authority for their label/target/session and removal; turn it off to edit a saved managed connection manually. Import is local and immediate, with connection retries shown per device. Named SSH sessions may omit a socket path.

The sidebar footer displays configured Herdr status-command text in a compact monospaced label. Search includes configured popup commands and enabled plugin actions/panes with their device/plugin context; unavailable scoped actions are disabled. Plugins and Herdr Commands also have native menu-bar entries. Config parse errors are visible beside the footer. Plugin discovery errors are visible in the Plugins menu.

Transient command windows use native floating windows and real Ghostty terminals with resize, selection, paste and physical Ctrl-C. Process exit closes the window; user close stops only that transient process. Herdr plugin panes are opened through RPC into a server-owned tab and attached in a floating window; reopening that tab raises the existing window. Disconnects preserve server processes. See [contract and validation details](docs/herdr-integration/VALIDATION.md).
