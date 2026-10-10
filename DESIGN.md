---
name: HerdrX
description: A compact native macOS workbench for terminals, coding agents and on-demand files.
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
  detail:
    fontFamily: "macOS system font"
    fontSize: "10pt"
  pane-title:
    fontFamily: "macOS system monospaced font"
    fontSize: "11pt"
    fontWeight: 400
  pane-title-focused:
    fontFamily: "macOS system monospaced font"
    fontSize: "11pt"
    fontWeight: 600
  file:
    fontFamily: "macOS system font"
    fontSize: "12pt"
  file-preview:
    fontFamily: "macOS system monospaced font"
    fontSize: "12pt"
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
  sheet-inset: "20pt"
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
    height: "44pt"
  search-result:
    height: "36pt"
    rounded: "{rounded.search-selection}"
    padding: "0pt 8pt"
  search-results:
    height: "320pt"
  search-footer:
    height: "28pt"
  files:
    width: "320pt"
  files-toolbar:
    height: "36pt"
    padding: "0pt 10pt"
  file-row:
    typography: "{typography.file}"
    height: "28pt"
  file-preview:
    typography: "{typography.file-preview}"
    padding: "{spacing.content-inset}"
  settings:
    width: "740pt"
    height: "560pt"
  file-manager:
    width: "800pt"
    height: "560pt"
    padding: "{spacing.sheet-inset}"
  creation-sheet:
    width: "480pt"
    padding: "{spacing.creation-inset}"
  reconnect:
    rounded: "{rounded.reconnect}"
    padding: "{spacing.content-inset}"
---

# Design System: HerdrX

## Overview

**Creative North Star: "Native workbench"**

HerdrX is a simple, clean native macOS workbench. Terminals own the visual field; compact navigation makes local shells, device workspaces and coding agents easy to reach. Files appear beside the terminal only when requested.

SwiftUI and AppKit supply system typography, familiar controls and keyboard behavior; Ghostty supplies the terminal canvas. Preserve HerdrX's name and the user-supplied purple diagonal slash on a white icon tile. Keep that identity in the app icon and product surfaces without repeating it as decoration across the workbench.

**Key Characteristics:**

- Terminal-first density with a single integrated top bar.
- Theme-aware surfaces, semantic system controls and explicit focus.
- Stable sidebar actions with compact, collapsible navigation groups.
- On-demand file browsing and native settings without decorative card chrome.

This is a source scan of the current native implementation, refreshed for `docs/parity/SPEC.txt` S01–S07. Frontmatter records observed implementation values in native points; it does not certify all functional or interaction acceptance criteria. The specification remains the target contract, and any implementation differences below remain visible rather than being silently promoted to new requirements. Source evidence: `App/Workbench.swift`, `App/Sidebar.swift`, `App/Tabs.swift`, `App/Theme.swift`, `App/Preferences.swift`, `App/Files.swift`, `App/Terminal.swift`, `App/WindowBehavior.swift` and theme wiring in `App/Main.swift`. Prior review images are not current-render acceptance evidence for this refresh.

## Colors

The palette combines explicit theme surfaces with native semantic text, controls and separators. Frontmatter contains only colors actually defined in `Theme.swift`; it does not translate dynamic macOS colors into fixed swatches.

### Primary

- **Theme accent:** `Theme.accent` supplies SwiftUI tint/accent and AppKit tab and pane focus. The default follows `NSColor.controlAccentColor`; the Catppuccin theme uses the frontmatter's violet accent unless the user chooses another accent.
- **Accent choices:** Graphite, Green, Blue, Purple, Amber, Pink, Red and Orange map to AppKit system color roles. Amber currently maps to `NSColor.systemYellow`. These values remain appearance-aware platform colors.
- **Selected navigation:** sidebar rows and tabs use accent fill at 0.18 opacity in light appearance and 0.20 in dark appearance, with a one-point accent outline at 0.22. Sidebar and tab hover use native primary/label color at 0.06 opacity. Search selection retains its lighter 0.14 wash, and file selection uses 0.18. Focused panes use the accent directly.

### Neutral

- **Workbench surface:** the default light/dark content tokens fill the workbench and pane-title cutouts. Catppuccin has its own light/dark content tokens; Dracula and Nord use their dark content tokens and default content in light appearance.
- **System surfaces and text:** files use `NSColor.windowBackgroundColor`; the font preview uses `NSColor.textBackgroundColor`. Standard labels, secondary captions and dividers retain native primary, secondary and separator roles. These are not the numeric reference palette in the specification.
- **Terminal surface, text and selection:** the default terminal tokens in frontmatter are explicit light/dark values from `Theme.apply()`. Catppuccin uses Ghostty's Latte/Mocha definitions; Dracula and Nord use their Ghostty dark definitions and Alabaster in light appearance. Their full palettes remain library-owned. Do not describe every light terminal as Alabaster.

Working and unread states use system blue; blocked uses system orange; inactive states use secondary emphasis. A half-filled, filled or outlined circle also conveys the state. Device connection dots use green/orange independently of agent status. These are functional signals, not additional brand accents.

**The Semantic Color Rule.** Keep platform colors semantic and source-defined theme colors explicit. Do not freeze a screenshot's appearance into a new palette.

## Typography

Use the macOS system font for navigation and native system monospaced type for pane titles and file text. No custom display family is present. Platform styles such as `.headline`, `.title2`, `.body` and `.caption` remain platform-defined instead of receiving fabricated point equivalents.

The frontmatter records the explicit hierarchy: regular/semibold tabs, regular/medium Space labels, Agent titles, secondary metadata, semibold group headers and small optional detail. Space and Agent rows retain three-point separation between their primary and secondary text. Long names truncate at the tail; full paths remain available through tooltips or selectable text. File names and the file-root path truncate in the middle where implemented.

Terminal typography defaults to the SF Mono token and remains user-selectable. Font size spans 9–22 points in half-point steps; line spacing spans 1–1.4 in 0.05 steps. Regular, Medium, Semibold and Bold apply only to the system mono choice. The settings preview uses native system monospaced type with the selected weight for SF Mono, a custom font for other families, and Chinese, ASCII and digits as sample content. It is a settings preview, not a substitute for checking a rendered Ghostty surface.

**The Reading Rule.** Preserve native text metrics and user-selected terminal typography; truncate navigation labels and retain their full context in tooltips.

## Layout

All measurements are macOS points. The outer window minimum is 980 × 620, enforced by `WindowBehavior`; the main scene's internal minimum height is separate. The hidden-titlebar layout keeps the system traffic lights and reserves 78 points at the left. The main detail uses the single integrated bar token for tabs and actions, followed by a native divider and the terminal canvas. There is no persistent bottom status bar or second device-title strip.

The sidebar uses the frontmatter's initial width, persists its width and visibility, and resizes from 200 to 480. Its one-point visible separator has a seven-point drag target, with double-click resetting the default. Below the traffic-light row, New, quick Space and Search remain fixed above the scrollable list; the device filter and Settings stay in the fixed footer. Group headers pin while scrolling, collapse persistently and disappear when their group is empty.

Sidebar content has the documented outer inset and four-point list spacing. Space/Agent content uses a 12-point leading icon column and the row column gap; two-line content uses the row line gap. Space rows use six-point vertical padding and eight-point corners. Agent rows use seven-point vertical padding and seven-point corners. Other sidebar rows retain the shared seven-point vertical padding and eight-point corners. Row height follows content, allowing real optional Agent metadata to add a line.

Tabs occupy compact natural widths: measured text plus 20 points, clamped to 40–200. Buttons sit two points from the strip edges, with two-point gaps; their height is in frontmatter. Long rows scroll horizontally. Pane layout follows normalized split rectangles. Each pane draws a one-point rectangular border with a 3.5-point base inset and an additional 3.5-point top clearance, placing the top border seven points below the canvas edge so the fourteen-point centered title remains inside the canvas; its terminal view starts four points from left and bottom, has width reduced by eight and height reduced by eighteen. This leaves room for the embedded title instead of a separate header bar. Split resize hit areas are six points wide.

The file area is closed initially. Its width persists, starts at the file token, resizes from 240 up to 60% of the available detail width, and resets on double-click. Its divider repeats the one-point line and seven-point hit target. At file-area widths of at least 520, a fixed 210-point tree sits beside the preview; below that threshold, selecting a file replaces the tree with the preview and exposes a Back button. This is native container adaptation, not a web viewport breakpoint.

Search uses the frontmatter's width, input/result/footer heights and horizontal inset; the results viewport is currently fixed at 320 points, including the empty state. Settings is a native split window with a 150-point navigation column and the documented overall size. Creation sheets and the two-ended File Manager use their own frontmatter dimensions rather than forcing every native form to one width.

**The Terminal Space Rule.** Keep the main detail area available to terminals; reveal file tools on demand and return their space when closed.

## Elevation & Depth

The workbench has no custom shadow vocabulary or explicit motion curve. Thin borders, native dividers, restrained selection fills and pane-title cutouts convey structure. Reconnect uses `.regularMaterial` above terminal content. Sheets, alerts, grouped forms and controls retain platform-managed depth, focus, hover and disabled treatment. Do not substitute decorative shadows for selection or focus.

## Shapes

Space rows, Agent rows, compact tabs and search results use their distinct frontmatter corner radii. The terminal font preview and reconnect overlay keep their own documented shapes. File rows remain rectangular; pane frames and internal splits remain rectangular in the scanned implementation. There is no implementation claim here for the specification's macOS 26 outer-corner refinement. Status glyphs are eight-point SF Symbols; device connection dots are six-point circles. Native settings controls retain their platform geometry.

## Components

### Buttons and native forms

Chrome actions use compact borderless SF Symbol buttons with action/shortcut help. Sidebar and search rows use plain buttons with full-row hit regions. New is a native menu; advanced Space and Agent creation remain native sheets with loading, disabled and error states. Settings uses a sidebar list and grouped forms for Appearance, Terminal, Agents, Notifications, Devices, Tailcat, Plugins, Updates and About. Keep HerdrX names and native plugin surfaces; no ACC settings category belongs here.

### Sidebar navigation and attention

Local shells, device Spaces, Agents and ordinary terminals occupy collapsible groups. Agent rows keep tool identity separate from execution status: the secondary label includes an SF Symbol, tool name and Space, plus device context when all devices are in scope. Codex uses braces, Claude a sun, Cursor a pointer, Gemini sparkles, Grok an asterisk, Kimi a moon, OpenCode code chevrons, Pi/Oh My Pi a function symbol and Copilot an airplane; unknown tools fall back to Terminal. These are native pictograms, not third-party logos.

Agent status uses a blue half-filled circle for working, an orange solid circle for blocked, blue solid for unread completion and secondary outline for read/idle/unknown states, with accessible state text. Optional runtime metadata appears only when supplied. Selection remains separate from hover and unread state. Device failures render near their device group with Retry rather than replacing the whole workbench.

### Tabs and panes

AppKit tabs use natural width, selected weight, the accent wash/outline and full-title tooltips. A neutral hover fill distinguishes the pointed-to tab without duplicating selected emphasis; a two-point accent insertion marker shows reorder position. Object menus act on the tab or pane under the pointer.

Pane titles are drawn into a cutout in the top border using the regular/focused mono roles. The cutout is fourteen points high, offset nine points from the border's left edge, with six-point text inset. Close controls use the frontmatter size and appear on hover or with VoiceOver; a separate matching restore control appears when zoomed. Ghostty surfaces remain mounted across workspace visibility changes, with hidden drawing suspended. Empty terminals use native `ContentUnavailableView`; exited/detached terminals receive the compact material reconnect action.

### Search

Jump uses a native rounded-border text field, receives initial focus, and combines type icon, one-line title and secondary context in each result. Arrow keys and pointer hover share selection; Return opens it and Escape closes the sheet. The footer exposes keyboard hints. Preserve the empty-state explanation and full object identity rather than relying on label text alone.

### Files and transfer

The file panel uses a compact toolbar, selectable root path, lazy tree, hidden-file toggle and refresh. Tree rows use native folder/document/link symbols, twelve-point indentation per depth and full-path help. Preview text is read-only, selectable system mono; images scale to fit inside a scroll view. Error and loading states remain explicit. The service limits preview to 2 MiB and rejects non-regular files; this source observation is not a claim of completed remote acceptance.

File Manager is a separate native sheet with local and target-device listings, path navigation, Name/Size/Modified columns, single-file transfer controls, conflict choices and visible byte progress. Device management and native plugin actions remain in Settings. Keep this support UI subordinate to the terminal workflow and avoid implying remote or Tailcat behavior is verified by its visual presence.

## Do's and Don'ts

### Do:

- Do retain HerdrX identity and native SwiftUI/AppKit controls.
- Do keep terminal content dominant, navigation compact and file tools on demand.
- Do use shape and accessible text with status color; keep device connection and agent execution states distinct.
- Do verify both appearances, long Chinese labels and the specified window sizes with the running native app.
- Do treat the source scan, rendered review and behavioral acceptance as separate evidence.

### Don't:

- Don't replace native controls or the real terminal with a web theme, raster mockup or simulated terminal.
- Don't restore a second fixed toolbar or a persistent bottom status bar.
- Don't invent fixed equivalents for macOS dynamic colors or platform text styles.
- Don't add decorative shadows, oversized branding or card containers around terminal panes.
- Don't invent runtime metadata, hide context behind controls or claim full parity from screenshots.
