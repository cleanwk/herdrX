---
name: Herd-X
description: A clean native macOS workbench for terminals and coding agents.
colors:
  terminal-dark-background: "#101012"
  terminal-dark-foreground: "#E2E2E2"
typography:
  tab:
    fontFamily: "macOS system font"
    fontSize: "12pt"
    fontWeight: 400
  tab-selected:
    fontFamily: "macOS system font"
    fontSize: "12pt"
    fontWeight: 600
  metadata:
    fontFamily: "macOS system font"
    fontSize: "11pt"
  section-label:
    fontFamily: "macOS system font"
    fontSize: "10pt"
    fontWeight: 600
  terminal:
    fontFamily: "SF Mono"
    fontSize: "13pt"
rounded:
  selection: "6pt"
  reconnect: "8pt"
spacing:
  row: "8pt"
  sidebar: "10pt"
  toolbar: "16pt"
  sheet: "20pt"
components:
  tab:
    typography: "{typography.tab}"
    rounded: "{rounded.selection}"
    width: "142pt"
    height: "30pt"
  tab-selected:
    typography: "{typography.tab-selected}"
    rounded: "{rounded.selection}"
    width: "142pt"
    height: "30pt"
  space-row:
    rounded: "{rounded.selection}"
    height: "48pt"
  reconnect:
    rounded: "{rounded.reconnect}"
    padding: "12pt"
---

# Design System: Herd-X

## Overview

The confirmed design direction is a simple, clean native macOS workbench. Terminals own the visual field; system controls and compact navigation make sessions easy to reach. Treat “native workbench” as the descriptive north star, without inventing a separate brand metaphor.

SwiftUI and AppKit supply system typography, dynamic colors, standard forms and familiar keyboard behavior. The original app icon is a recognizable ivory H-shaped herd animal on charcoal; retain its identity without turning it into decorative imagery across the interface.

**Key Characteristics:**

- Terminal-first density with restrained chrome.
- Appearance-aware system surfaces and accent selection.
- Familiar native controls, SF Symbols and keyboard access.
- Flat navigation with clear selected-space and focused-pane states.

## Colors

The chrome follows macOS semantic colors; these are dynamic platform values, not fixed CSS equivalents. Fixed terminal dark colors are recorded in frontmatter.

### Primary

- **System accent:** SwiftUI `Color.accentColor` and AppKit `NSColor.controlAccentColor`. Selection backgrounds use 0.14 opacity. Selected tabs also use a 0.5-opacity accent stroke; focused terminal borders use 0.7 opacity. The actual hue follows the user's macOS accent setting.

### Neutral

- **Window surface:** `NSColor.windowBackgroundColor` for the workbench background.
- **Separator:** `NSColor.separatorColor` for navigation boundaries and terminal gutters.
- **Text:** native primary text and `.secondary` for metadata, captions and shortcut hints.
- **Terminal dark surface and text:** the frontmatter's terminal colors belong exclusively to the dark terminal theme. Light terminals use Ghostty's `.alabaster` theme; its palette is library-owned and is not extracted here.

Green and orange system colors communicate connection and agent states alongside visible text. They are functional signals, not additional brand accents.

**The Semantic Color Rule.** Keep chrome bound to platform semantic colors. Do not freeze a screenshot's appearance into a new palette.

## Typography

Use the macOS system font for interface text and SF Mono by default for terminals. No custom display family is present. SwiftUI `.headline`, `.title2`, `.title3`, `.body`, `.callout` and `.caption` retain platform-defined sizing rather than fabricated fixed equivalents.

The compact explicit hierarchy is recorded in frontmatter: regular and semibold tabs, small metadata and semibold uppercase section labels. Device labels are semibold and space labels medium. Terminal font family is user-selectable from fixed-pitch families; size ranges from 9–22 points and line spacing from 1–1.4. The documented terminal token is the default, not a restriction on user settings.

**The Reading Rule.** Preserve terminal legibility and native text metrics; truncate long navigation labels instead of shrinking their type.

## Layout

All native measurements use points. The workbench stacks a 48-point toolbar, horizontal content area and 26-point status bar, separated by native dividers. The toolbar leaves 80 points before the title for window controls. The sidebar starts at 260 points, resizes between 180 and 450, and resets to its initial width on double-click. It has a one-point separator with an eight-point drag target.

Sidebar groups use 18-point separation and four-point internal spacing. The tab strip is 38 points high. Tabs occupy 150-point slots with four-point insets. Labels truncate at the tail; space metadata truncates in the middle. Terminal splits follow normalized pane rectangles with one-point insets and six-point resize handles. The window adapts through flexible content and resizable panes; there are no web breakpoints.

Jump is a 520-point-wide sheet with 20-point padding, 16-point content spacing and a 320-point result viewport. Preferences is a 680 by 560-point native tabbed window with 16-point outer padding and grouped forms.

## Elevation & Depth

The workbench has no custom shadow vocabulary. Native dividers, semantic surfaces and subtle accent fills convey structure. Reconnect uses `.regularMaterial` over terminal content. Standard sheets, alerts and controls retain platform-managed depth, focus and disabled treatment. No custom animation duration or easing is specified.

## Shapes

Selected navigation and tabs share the gently curved selection radius from frontmatter. The reconnect overlay uses the larger radius. Pane boundaries remain rectangular; thin separator gutters express splits without card framing. Status dots are six-point circles. Standard settings inputs and buttons keep native geometry.

## Components

### Buttons

Toolbar buttons are borderless SF Symbol controls, with tooltips naming their action and shortcut. Sidebar and Jump rows are plain buttons with full-row hit areas. Forms use standard native buttons, including disabled states. Do not add a custom primary-button visual hierarchy where the platform already supplies one.

### Navigation

The sidebar groups local shells, devices and spaces, then agents when present. Selection uses the system accent wash and the selection shape. Device connection text remains distinct from agent execution labels. Custom AppKit tabs use the frontmatter's geometry and typography; selected tabs add the subtle accent outline. Drag reorder shows a two-point accent insertion marker. Each tab exposes its selected state to accessibility and its full title as a tooltip.

### Inputs / Fields

Jump uses a native rounded-border text field, focused when the sheet opens. Arrow keys move through results, Return activates the current result, and Escape cancels. Preferences uses native grouped forms, pickers, text fields, sliders and toggles. Keep platform focus behavior rather than introducing a CSS-like glow.

### Terminal Canvas

Full-fidelity Ghostty surfaces remain mounted while switching workspaces. Hidden panes retain dimensions and suspend drawing. Focus is expressed by the accent boundary, not a colored terminal background. Split handles use directional resize cursors. Reconnect appears as a compact material overlay with an action; an empty canvas uses native `ContentUnavailableView` and Open Shell.

### Status and Extension Surfaces

The bottom status bar pairs a small dot with connection text, current agent or Shell, and the Jump hint. Agent rows pair state dots with readable state labels. Extension settings follow the same native list/detail language, system headings and secondary captions, with monospaced selectable execution output.

## Do's and Don'ts

### Do:

- **Do** use semantic system colors and verify both macOS appearances.
- **Do** keep terminal content dominant and controls compact.
- **Do** pair status color with readable text and preserve native keyboard focus.
- **Do** retain the recognizable original app icon.

### Don't:

- **Don't** replace native controls with a web-style component theme.
- **Don't** invent fixed equivalents for dynamic colors or platform text styles.
- **Don't** add decorative shadows, oversized branding or card chrome around terminal panes.
- **Don't** hide long labels behind controls; retain truncation and tooltips.
