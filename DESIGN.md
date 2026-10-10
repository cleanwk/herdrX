---
name: HerdrX
description: A quiet native macOS workbench for terminal tasks, devices and automatically detected agents.
colors:
  content-light: "#F6F6F6"
  content-dark: "#181818"
  terminal-light-background: "#FFFFFF"
  terminal-light-foreground: "#242424"
  terminal-light-selection: "#C6DAFB"
  terminal-dark-background: "#101012"
  terminal-dark-foreground: "#E2E2E2"
  terminal-dark-selection: "#30466C"
  catppuccin-accent: "#8B6CEF"
  catppuccin-content-light: "#EFF1F5"
  catppuccin-content-dark: "#1E1E2E"
  dracula-content-dark: "#282A36"
  nord-content-dark: "#2E3440"
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
    fontSize: "13.5pt"
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
    fontWeight: 400
  search-input:
    fontFamily: "macOS system font"
    fontSize: "14pt"
  search-context:
    fontFamily: "macOS system font"
    fontSize: "10.5pt"
  terminal:
    fontFamily: "SF Mono"
    fontSize: "13pt"
rounded:
  tab: "5pt"
  search-selection: "6pt"
  font-preview: "6pt"
  sidebar-selection: "8pt"
  agent-selection: "7pt"
  reconnect: "8pt"
  pane-outer-bottom: "10pt"
spacing:
  sidebar-row-x: "8pt"
  sidebar-row-y: "7pt"
  space-row-y: "6pt"
  sidebar-inset: "10pt"
  row-column-gap: "6pt"
  row-line-gap: "3pt"
  list-gap: "4pt"
  content-inset: "12pt"
  toolbar-inset: "16pt"
  connections-inset: "20pt"
  creation-inset: "24pt"
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
  sidebar-row:
    rounded: "{rounded.sidebar-selection}"
    padding: "7pt 8pt"
  space-row:
    typography: "{typography.space}"
    rounded: "{rounded.sidebar-selection}"
    padding: "6pt 8pt"
  agent-row:
    typography: "{typography.agent}"
    rounded: "{rounded.agent-selection}"
    padding: "7pt 8pt"
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
  settings:
    width: "740pt"
    height: "560pt"
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

HerdrX is a quiet native macOS workbench. Terminals own the visual field; compact navigation keeps each task, device and session clear. Neutral controls recede around task names, readable state labels and focused terminal content.

SwiftUI and AppKit supply system typography, familiar controls and keyboard behavior; Ghostty supplies the real terminal canvas. Preserve HerdrX's name and the user-supplied purple diagonal slash on a white icon tile. The original artwork, native Icon Composer packaging and provenance remain documented in [Resources/Icon/README.md](Resources/Icon/README.md) and [Resources/Icon/Prompt.txt](Resources/Icon/Prompt.txt); this refresh creates no raster assets.

**Key Characteristics:**

- Terminal-first density with one integrated top bar.
- Neutral chrome, semantic text and distinct selection, focus and execution signals.
- Task-first, two-line Agent rows with device and session context available.
- Compact native search, four-section settings and adjustable pane boundaries.

This source-observed refresh follows [PRODUCT.md](PRODUCT.md), the [workbench direction](.impeccable/surfaces/app-workbench-swift.md) and [UX audit SPEC](docs/ux-audit/SPEC.md), with [SCOPE.md](docs/ux-audit/SCOPE.md) overriding earlier parity and conditional transfer requirements. Agent launching, command overrides, file trees, previews, transfer and attachment delivery are removed. Automatic Agent recognition, state and navigation remain. Frontmatter records implemented primitives in native points; dynamic platform roles and constraints live in the JSON sidecar.

Sources: `App/Workbench.swift`, `Sidebar.swift`, `Tabs.swift`, `Terminal.swift`, `Preferences.swift`, `Theme.swift`, `Navigation.swift`, `SearchInput.swift` and `WindowBehavior.swift`. Supplied captures were inspected for [light 980/200](docs/ux-audit/screenshots/workbench-light-980-200.png), [light 980/260](docs/ux-audit/screenshots/workbench-light-980-260.png), [dark 1440/480](docs/ux-audit/screenshots/workbench-dark-1440-480.png), [empty search](docs/ux-audit/screenshots/search-empty-light.png) and [About & Updates](docs/ux-audit/screenshots/about-updates.png). The refreshed workbench captures show native label-colored state words and pane titles; token definitions still follow source rather than sampled pixels. This document does not certify contrast across every accent, VoiceOver operation, IME behavior, performance or the full C01–C90 matrix. Current acceptance belongs in [RESULTS.md](docs/ux-audit/RESULTS.md) and the finish review.

## Colors

Explicit theme surfaces support native semantic text, restrained selection and functional state signals. Frontmatter preserves colors defined by `Theme.swift`; platform colors remain dynamic instead of becoming screenshot-derived hex tokens.

### Primary

- **Theme accent:** `Theme.accent` follows `NSColor.controlAccentColor` by default. Catppuccin supplies the violet token when the user follows the theme. Graphite, Green, Blue, Purple, Amber, Pink, Red and Orange use their AppKit system roles; Amber maps to `NSColor.systemYellow`.
- **Selection and focus:** sidebar rows and tabs use accent fill at 0.18 opacity in light appearance and 0.20 in dark appearance, with a one-point accent outline at 0.22. Search selection uses a 0.14 accent wash. The active pane uses an accent border only while its window is key.
- **Execution signals:** working and unread glyphs use the theme accent; blocked glyphs use system orange. Agent state words stay `.primary`. Active pane main titles stay `NSColor.labelColor` and gain semibold weight. Accent choice must not become unchecked small-text color.

### Neutral

- **Workbench ground:** default, Catppuccin, Dracula and Nord surfaces use the frontmatter tokens. Dracula and Nord retain the default workbench ground in light appearance.
- **Chrome and text:** the workbench uses primary foreground and a secondary-label tint for action controls. Labels use native primary/label roles, context uses secondary roles, and separators use `NSColor.separatorColor`. Sidebar and tab hover use primary/label color at 0.06 opacity. The font preview uses `NSColor.textBackgroundColor`.
- **Terminal ground, text and selection:** default Ghostty colors are explicit light/dark tokens. Catppuccin uses Ghostty Latte/Mocha; Dracula and Nord use their Ghostty dark definitions and Alabaster in light appearance. Library-owned terminal palettes remain library-owned. Follow Herdr resolves supported families from local configuration and falls back to Default for unsupported names.

Connected device headers use a small neutral filled circle; offline headers use an orange outline. Device connection and Agent execution remain separate signals. Shape and text carry meaning alongside color.

**The Semantic Color Rule.** Keep platform colors semantic and source-defined theme colors explicit. Do not freeze a screenshot's appearance into a new palette.

**The Readable State Rule.** Keep Agent state words and pane main titles in native label colors; put saturated status and focus color on glyphs and borders.

## Typography

Use the macOS system font for navigation and system monospaced type for pane titles and context. No custom display family is present. Native styles such as `.title2`, `.body` and `.caption` keep platform metrics.

The frontmatter records the explicit hierarchy: regular/semibold tabs, regular/medium Space labels, Agent task titles, metadata and semibold group headers. Agent rows are always two lines: task title and state glyph, then tool/Space/device context and a readable state word. Runtime model/account/context/quota details belong in full help when supplied; they do not create a third row or fabricated metadata. Space rows separate title and branch/directory context with the same line gap.

Pane titles pair a primary monospaced task name with smaller secondary context. Main titles truncate at the tail and pane context in the middle; help and accessibility labels retain full object identity. Search pairs a primary result title with the search-context role. Its borderless AppKit input uses the search-input role.

Terminal typography defaults to SF Mono and remains user-selectable. Font size spans 9–22 points in half-point steps; line spacing spans 1–1.4 in 0.05 steps. Regular, Medium, Semibold and Bold apply only to SF Mono. The native preview includes Chinese, ASCII and digits. Preserve mouse reporting, thin strokes, copy-on-select and the one-time Ghostty font import; terminal text copy/paste remains available. A settings preview does not establish actual Ghostty rendering or input acceptance.

**The Reading Rule.** Preserve native text metrics and user-selected terminal typography; truncate navigation labels and retain their full context in tooltips.

## Layout

Measurements are macOS points. `WindowBehavior` enforces a 980 × 620 minimum outer window; this differs from the scene's internal content minimum. The hidden titlebar retains system traffic lights with a 78-point left reserve. The detail region starts with the integrated-bar token, a native divider and terminal canvas. Tabs, New Terminal Tab and Pane Layout share this single row.

The sidebar starts at the frontmatter width, persists width and visibility, and resizes from 200 to 480. Its visible separator is one point; its drag target is seven points. Double-click restores the default. The splitter exposes its value and bounds to accessibility, accepts left/right keyboard adjustment and changes in 20-point increments. The New Space action, named-directory options and Search stay above the scrollable groups. Device Filter and Settings stay in the fixed footer. Native section headers pin while scrolling, collapse persistently and omit empty non-device groups.

Space and Agent rows keep the shared horizontal padding, distinct vertical padding and corner tokens. The list uses the documented outer inset and list gap. Agent title and state glyph share the first line; context yields space to the fixed-width state word on the second. Group/device headers are secondary, leaving task names dominant at both narrow and wide sidebar widths.

Tabs use measured text plus 20 points, clamped to 40–200, with two-point strip insets and gaps. Overflow scrolls horizontally; changing selection reveals the selected tab. Pane layout follows normalized split rectangles. Frames have a 3.5-point base inset and another 3.5 points of top clearance for the embedded title. Terminal views start four points from the left and bottom, reduce width by eight and height by eighteen. Pane split handles are seven points wide, expose adjustable accessibility values and move five percentage points per keyboard/accessibility increment within minimum-size bounds. Split availability preserves room for at least 24 columns and six rows using the current font instead of shrinking text.

Search has the fixed width and header/result/footer tokens, but its results region is content-sized: `min(320, max(44, resultCount × 36))` points. An empty search therefore has a 44-point explanation region. Settings is a native split window with a 150-point navigation column and the frontmatter dimensions. New Space remains a compact named-directory sheet with its own width and inset.

**The Terminal Space Rule.** Keep the main detail area available to real terminal panes and keep supporting navigation compact.

## Elevation & Depth

The workbench has no custom shadow vocabulary or motion curve. Thin borders, native dividers, restrained selection fills and pane-title cutouts convey structure. The recovery overlay uses `.regularMaterial`. Sheets, alerts, grouped forms and controls retain platform-managed depth, focus and disabled treatment. Native settings group containers do not establish a decorative card system for the workbench.

## Shapes

Sidebar rows, Agent rows, tabs, search results, font preview and recovery overlay use their frontmatter radii. Pane frames and internal splits are rectangular. On macOS 26 and later, bottom panes use the pane-outer-bottom radius at the right outer corner and at the left outer corner when the sidebar is hidden; older systems retain rectangular outlines. The source establishes this conditional behavior, without claiming a lower-version runtime pass.

Agent status glyphs are eight-point SF Symbols and device header glyphs are six-point circles. Native settings controls retain platform geometry. Pane close and restore controls use the same compact dimensions; no extra pane toolbar is introduced.

## Components

### Chrome actions and forms

Borderless SF Symbol actions and native text labels keep primary chrome neutral. New Space performs quick creation; its adjacent options menu opens the named-directory sheet. The tab plus creates a terminal tab, and Pane Layout contains split and zoom/restore actions with capability-aware disabled states. Creation displays busy/error state and holds its chosen device through submission. Object menus identify the clicked Space, Tab or Pane; destructive confirmations state their affected object and effect.

### Sidebar navigation and attention

Groups cover local shells, device Spaces, detected Agents and ordinary terminals. Agent task titles come from the same display-title path as their panes. Secondary content combines tool, Space and device when all devices are visible. Full help carries task, device/session, directory and real runtime details. Selection, hover and unread attention are independent treatments.

Agent status uses a half-filled circle for working, a filled circle for blocked or unread completion, and an outline for other states. A readable state word accompanies the glyph in Agent rows; group summaries and search glyphs expose accessible labels. Codex uses braces, Claude a sun, Cursor a pointer, Gemini sparkles, Grok an asterisk, Kimi a moon, OpenCode code chevrons, Pi/Oh My Pi a function and Copilot an airplane. Unknown tools use Terminal. These are SF Symbol pictograms, not third-party logos. Connection failures remain beside their device group with Retry and explicit cached/offline context.

### Tabs, pane titles and splitters

Tabs use natural widths, selected semibold weight, accent wash/outline and full-title tooltips. Neutral hover does not duplicate selection. A two-point accent insertion marker and edge scrolling support reordering. Tabs expose radio-button selection and pane-count help to accessibility.

A pane title is embedded in the top border cutout, pairing the primary task with secondary device/session context. The cutout is fourteen points high, starts nine points from the frame's left edge, and uses four points before main text and ten points between text runs. Main text gets at most 64% of the available title width when context exists. Its color is always labelColor; only the focused pane in the key window uses semibold weight and an accent border. Close appears on hover or when VoiceOver is enabled; zoom exposes Restore. Full pane context is assigned to the terminal's help and accessibility label.

Native Ghostty surfaces remain mounted when workspaces are hidden; layout and explicit focus requests are separate. Hidden views are not assigned visible frames. Empty workbenches use `ContentUnavailableView` with Open Shell. Ended local shells offer Reopen with exit information; ended server attachment offers Reconnect with ownership confirmation. These source behaviors are not a complete lifecycle acceptance claim.

### Search

Search uses a borderless native `NSTextField` with a magnifier, initial field focus and keyboard hints. Result rows pair a type/tool pictogram, title, context and optional Agent status. Arrow keys and hover share selection; keyboard navigation keeps the target visible. Return validates the target before opening; Escape, Cancel and sheet close return through the owning presentation. Field-editor command handling leaves marked text to the input method. The compact empty state explains that no spaces, terminals or agents match. Full IME and focus behavior still require the declared native acceptance checks.

### Settings

Four top-level sections organize native controls:

- **Appearance:** Appearance and Behavior tabs cover appearance, language, palette, accent and notification preferences.
- **Terminal:** typography, rendering/input preferences, Ghostty font import, preview and defaults.
- **Connections:** Devices plus explicit advanced segments for Tailcat and generic Herdr Plugins.
- **About & Updates:** version, installation context, project link, Homebrew update command, eligible direct-download update action and open-source notices.

Connection editing uses a draft form. Update presentation distinguishes verified Homebrew ownership from a merely detected installation, and gives a reason when direct updates are unavailable. Tailcat, plugins and notifications retain native support UI; their presence does not certify external-service behavior.

## Do's and Don'ts

### Do:

- Do retain HerdrX identity, original icon provenance and native SwiftUI/AppKit controls.
- Do keep terminal content dominant, task names primary and device/session context available.
- Do use native label colors for state words and pane main titles, with shape and color for status glyphs.
- Do preserve Ghostty appearance, font and input preferences while refining chrome.
- Do verify both appearances, long Chinese labels, keyboard navigation and accessible splitters in the running native app.
- Do keep source observations, supplied captures and completed runtime acceptance separate.

### Don't:

- Don't restore Agent launching, command overrides, file trees, previews, transfer or attachment delivery removed by current scope.
- Don't replace native controls or real terminal content with a web theme, raster mockup or simulated terminal.
- Don't restore a second fixed toolbar or persistent bottom status bar.
- Don't invent fixed equivalents for macOS dynamic colors or platform text styles.
- Don't add decorative shadows, oversized branding or card containers around terminal panes.
- Don't invent runtime metadata or claim full contrast, input, accessibility or parity acceptance from screenshots.
