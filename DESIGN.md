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
    fontSize: "10pt"
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
  pane-outer-bottom: "10pt"
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
  canvas-top-clearance: "6pt"
  appearance-row-gap: "7pt"
  appearance-inner-gap: "4pt"
  appearance-inset-x: "25pt"
  settings-inset-top: "20pt"
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
    height: "24pt"
  tab-selected:
    typography: "{typography.tab-selected}"
    rounded: "{rounded.tab}"
    height: "24pt"
  pane-title:
    typography: "{typography.pane-title}"
    height: "14pt"
  pane-title-focused:
    typography: "{typography.pane-title-focused}"
    height: "14pt"
  pane-close:
    width: "20pt"
    height: "20pt"
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
    width: "150pt"
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

## Colors

The selected family supplies the shared terminal/workbench ground. Explicit per-family navigation text roles keep ordinary labels restrained; independent accents identify selection and focus. Terminal ANSI colors remain a separate set of roles.

### Primary

- **Blue, Graphite, Green, Cyan, Purple, Amber, Pink, Red and Orange:** the paired light/dark frontmatter tokens are explicit app-defined seeds, not aliases for AppKit system colors. Raw `Theme.selection` keeps the chosen hue for translucent fills; `Theme.accent` adjusts its shade for readable text, focus and native control tint. Follow Theme chooses Amber for Gruvbox/Vesper, Pink for Rosé Pine, Purple for Dracula, Cyan for Nord and Blue for the remaining families.
- **Space selection:** accent fill at 0.13 light / 0.20 dark with a one-point outline at 0.24. **Agent selection:** stronger fill at 0.25 light / 0.30 dark without a visible outline. Hover uses theme foreground at 0.05.
- **Tab selection:** accent fill at 0.18 light / 0.20 dark with a one-point outline at 0.22. Search selection uses 0.14. Active pane outlines and their semibold main titles use accent only while the window is key; inactive titles use theme secondary.

### Secondary

- **Success green:** completed/idle Agent state words and connected-device dots. Done/idle glyphs remain subdued secondary outlines, so the row does not duplicate a large green signal. Success, warning and failure seeds use the same contrast-aware surface checks as app text.
- **Warning amber:** blocked/waiting-input state words and glyphs. **Failure red:** offline-device dots. Working or unread state words use accent; unknown state uses theme secondary. Readable text and different glyph shapes accompany these colors.

### Neutral

- **Catppuccin ground and text:** HerdrX Default currently resolves to Latte/Mocha, as does the explicit Catppuccin family. The prior white/grey default tokens are obsolete.
- **Semantic text and palette-derived chrome:** `Theme.content` uses the selected definition's background; navigation foreground starts from the family's explicit frontmatter foreground seed. Chrome blends background toward that seed by 0.025 light / 0.06 dark. Secondary starts from a 0.20 blend of that seed toward background in both appearances. `ThemeColors.readable` then adjusts foreground, secondary, accent and state roles toward black or white only as needed to reach 4.5:1 against canvas, chrome, hover and the strongest sidebar/tab selections. Unfocused pane borders use adjusted foreground at 0.16. Native settings controls retain platform text and rendering; app tint follows the selected accent.
- **Tokyo Day slate:** HerdrX adapts the upstream blue default to the `tokyo-light-foreground` token for terminal default, cursor, selection foreground and ANSI 0, with `tokyo-light-ansi-bright-black` for ANSI 8. Cursor text uses the background. This is an authored adaptation, not an incorrectly copied upstream definition.
- **Gruvbox Light and Rosé Pine Dawn:** the named HerdrX light definitions set ANSI 0 to each upstream default foreground so black text remains dark on pale diff fills.
- **Dracula and Vesper light companions:** the frontmatter holds HerdrX-authored ground/text pairs. Source ANSI brightness is first capped at 0.55, selection uses the source-defined companion color, and cursor follows foreground. The chromatic adjustment below then applies. These companions are not upstream official light variants.

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

Pinned Ghostty definitions remain the source for each palette, with the named HerdrX adaptations above. Chromatic ANSI slots 1–6 and 9–14 receive hue-preserving shade adjustments toward 4.5:1 against the terminal canvas; changing a palette slot also changes it when a program uses that slot as a background. Slots 0/7/8/15 stay source-defined except the named light adaptations. Ghostty minimum contrast is 1, faint opacity is 0.85, and cursor text is mapped when supplied. Raising Ghostty's minimum contrast to 4.5 replaces failing colors with black/white in the pinned renderer and loses hue distinctions. Explicit indexed colors outside the adapted ANSI slots, RGB output and arbitrary foreground/background pairs retain application meaning and are not universally contrast-certified.

Follow Herdr reads local `~/.config/herdr/config.toml` `[theme].name`, resolves a supported family and falls back to Catppuccin for absent/unrecognized names. It does not edit Herdr configuration. System/Light/Dark controls appearance independently from family and accent. System selection and the native callback are evidenced; a macOS-driven appearance transition was not exercised.

**The Theme Continuity Rule.** Apply the selected family to chrome and terminal together, preserve independent appearance/accent preferences, and keep existing sessions mounted when colors change.

**The State Meaning Rule.** Keep selection, pane focus, Agent execution and device connection as distinct signals, with state text and glyphs alongside color.

**The Text Role Rule.** Use semantic app roles for navigation and status, keep raw selection hue separate from readable accent text, and do not recolor arbitrary terminal output to claim universal contrast.

## Typography

Use native macOS system type for navigation and settings, and system monospaced type for pane titles/context. The frontmatter records the explicit hierarchy; no custom display type is used. Space and Agent names have the same size. Space selection becomes medium, selected tabs become semibold, and focused pane titles become semibold. Metadata and group headings remain smaller than task names.

Space rows carry title plus branch/directory; Agent rows carry task plus status glyph, then tool/Space/device context plus a fixed-width state word. Both stay two lines. Long labels truncate before displacing status; help retains full identity and supplied runtime details. Agent metadata is never fabricated to fill a row. Pane main titles truncate at the tail, secondary context in the middle.

Terminal font defaults to Maple Mono CN when installed, otherwise SF Mono, using the frontmatter terminal size. Existing selected fonts and sizes remain intact. Size spans 9–22pt in 0.5pt steps; line spacing spans 100–140% in 5% steps, with 100% as the default. The visible SF Mono weight control offers Light, Regular and Medium; saved legacy Semibold/Bold values are still understood by the preview. Other families disable this control. Thin strokes and copy-on-select default on; mouse reporting defaults off. Restore Defaults returns those settings and Regular weight. Import from Ghostty reads font-family/font-size from a selected file; it is not a continuous settings sync. The preview uses the selected font with Chinese, ASCII and digits.

**The Reading Rule.** Keep compact native navigation type, preserve user terminal preferences, and retain full context in help when labels truncate.

## Layout

Measurements are macOS points. The original workbench reference is 3840 × 2100 pixels at 2× Retina; use original pixels divided by two when comparing it. A viewer's resized preview is not a 1× source. `WindowBehavior` enforces a 980 × 620 minimum outer window. The titlebar is hidden with a 78pt traffic-light reserve. The detail region contains the integrated tab bar, divider, top canvas clearance and real terminal panes.

The sidebar uses the default width token only when no saved width exists, persists width/visibility, and resizes from 200 to 480pt. Double-click restores the same default without a migration that overwrites existing widths. A one-point separator has a seven-point drag target; keyboard adjustment uses 20pt increments. New Space/options/Search remain above the scrollable groups; Device Filter and Settings remain in the footer. Device groups pin and collapse persistently; the Agent group is omitted when empty. There are no independent Shell or Terminals groups.

Space and Agent text starts approximately 36pt from the window's left edge: sidebar inset + row padding + content indent. Two native text lines, their shared line gap and distinct vertical padding produce approximately 45pt Space and 51pt Agent fills. These are rendered targets, not additional fixed-height constraints. Device connection dots follow the device name. State words reserve their own width at the Agent row's trailing edge.

Tabs use measured text plus 20pt, clamped to 40–200pt, with two-point strip inset and gaps. Overflow scrolls horizontally; selection reveals the active tab. Pane frames follow normalized split rectangles with a 3.5pt base inset and another 3.5pt at the title edge. Added canvas top clearance places the first pane outline approximately 42pt below the window top while preserving the tab-bar height. Terminal views start four points from left/bottom and reduce width by eight and height by eighteen. Split handles are seven points wide; keyboard/accessibility adjustment moves five percentage points within computed minimum sizes. The split command aims to preserve at least 24 columns and six rows instead of shrinking font preferences.

Settings uses six native toolbar icon tabs. Frontmatter dimensions describe each selected tab's content frame, excluding the OS toolbar/titlebar. Appearance's labels are 48pt wide with a 10pt gap after the horizontal inset, placing controls at about 83pt. The row gap and inner helper/accent gap use their frontmatter tokens. The accent row contains nine circles plus Follow Theme. Terminal settings uses a native grid, aligned font/size/weight/spacing fields, checkbox explanations, import/reset actions and a preview. Connections and Tailcat use the wider frame; scrollable forms may extend below the viewport.

The device popover offers All Devices, two-line identity/source rows, connection dots, a current-selection checkmark and Add Device. Its device list is capped at `min(360, deviceCount × 46)`pt. Search uses the frontmatter width and header/result/footer dimensions; the results region is `min(320, max(44, resultCount × 36))`pt. New Space remains a compact named-directory sheet.

**The Terminal Space Rule.** Keep the main detail area available to real Space-owned terminal panes and keep supporting navigation compact.

## Elevation & Depth

There is no authored shadow or motion vocabulary. Theme surfaces, thin outlines, selection fills and pane-title cutouts convey structure. Native popovers, sheets, alerts, controls and grouped forms retain platform depth and focus treatment. The recovery overlay uses `.regularMaterial`. A settings group is not a decorative card pattern for the workbench. Capture badges and cursor highlights are tooling overlays, not product design elements.

## Shapes

Use the component-specific frontmatter radii for rows, tabs, preview, search and recovery. Pane outlines and internal split boundaries remain rectangular. On macOS 26+, bottom panes round the right outer corner and the left outer corner when the sidebar is hidden; earlier systems use rectangular outlines. This is source behavior, not an older-OS runtime pass. Agent glyphs use eight-point SF Symbols; connected/offline device dots are six-point filled circles. Accent controls are circular, with a 1.5pt selected ring. Native settings controls retain OS geometry.

## Components

### Workbench actions and navigation

Compact borderless native buttons use SF Symbols with localized labels/help. New Space offers quick creation and a named-directory option. The tab plus creates a terminal tab within the selected Space; Pane Layout contains right/down splits and zoom/restore with capability-aware disabled states. Sidebar content comprises device Spaces and automatically detected Agents. Search also reaches the ordinary terminals within Spaces. The empty canvas says Choose a Space and offers New Space. Agent launch and independent Shell entry points do not return.

### Agent rows and device status

Task titles share the pane display-title source. Context combines tool, Space and device when multiple devices are visible. Working uses a half-filled circle; blocked/unread uses a filled circle; other states use an outline. State text carries the semantic color rules above. Codex, Claude, Cursor, Gemini, Grok, Kimi, OpenCode, Pi/Oh My Pi and Copilot use native SF Symbol pictograms; these are not vendor logos. Device status is separate: green connected/red offline, with accessible status and adjacent error/retry context. A failed connection can retain a clearly marked cached snapshot.

### Tabs, pane titles and splitters

AppKit tabs combine native type, natural widths, accent selection and neutral theme hover. Reordering shows a two-point accent marker and edge scrolling. Tabs expose radio-button selection and pane-count help.

Pane titles sit in a background-colored top-border cutout. The cutout begins nine points inside the pane frame, has four points before the main text and ten points between main/context runs. Main text receives at most 64% of available title width when context exists. Active key-window panes use accent outlines/titles; inactive panes use theme separator/secondary. Close appears on hover or when VoiceOver is enabled; zoom exposes Restore. Full title/context remains attached to the terminal's help and accessibility label. Native splitters expose values, bounds and keyboard/accessibility adjustment.

Ghostty surfaces remain mounted as workspaces are hidden. Layout and explicit focus requests are separate, and hidden views are not assigned visible frames. Ended attachments offer Reconnect with ownership confirmation where required. Removing independent Shell support does not remove Space-owned PTYs or terminal settings.

### Search and forms

Search uses a borderless native AppKit field, stable result identities, two-line context and shared hover/keyboard selection. Arrow keys select, Return opens and Escape cancels; marked text is respected by the source implementation. New Space captures the intended device/name/directory through submission, shows validation/error/busy state and restores focus appropriately on cancel. Object context menus and destructive confirmations identify the affected Space, Tab or Pane.

### Settings

The six top-level tabs are Appearance, Terminal, Connections, Notifications, Tailcat and About. Connections contains Devices and Advanced: Plugins. Appearance separates mode, palette, accent and language. `PreferenceMenu` uses an actual `NSPopUpButton`; the palette menu contains twelve choices and a separator after Default/Follow Herdr. Its update comparison excludes separator items so an unchanged menu is not rebuilt during ordinary view updates. Native keyboard, focus, disabled and popup behavior remain intact.

Terminal preferences and its actual-font preview follow Typography. Notifications has a dedicated native page; Tailcat has its own identity/connection page. About uses the 420×410pt content frame for version/project, updates and notices. Native controls present automatic checks, optional automatic download/install, status, last check, failure details, manual update action and release notes. A spinner appears only for a pending manual check; canceled checks/downloads clear progress and leave retry available. Status copy distinguishes a downloaded/verified update from one ready to install on quit.

One app-lifetime Sparkle updater serves both the application-menu Check for Updates action and About. Automatic checks default on at a 24-hour interval while the app runs; automatic downloads default off and persist after opt-in. Both Homebrew and direct installations use this flow. Background downloads install on quit; Herdr-owned sessions continue independently. Development builds disable updates unless the isolated fixture environment enables them. The release pipeline requires signed feed and archive verification; this is separate from Apple Developer ID signing/notarization and does not mean these changes have been published. See [updater validation](docs/app-updates/VALIDATION.md) for runtime proof and remaining limits.

## Do's and Don'ts

### Do:

- Do retain HerdrX identity, original icon provenance and native SwiftUI/AppKit/Ghostty rendering.
- Do follow the ACCM reference's compact spacing using original Retina pixels and native points.
- Do keep ten theme families plus Default/Follow Herdr, with appearance and accent independent.
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
