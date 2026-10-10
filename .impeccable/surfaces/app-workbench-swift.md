---
version: 1
slug: "app-workbench-swift"
primary_target: "App/Workbench.swift"
related_targets: ["App/Terminal.swift","App/Sidebar.swift","App/Tabs.swift","App/Preferences.swift","App/PreferenceMenu.swift","App/Theme.swift","App/ThemeColors.swift","App/DeviceSwitcher.swift","App/Updater.swift","App/Main.swift"]
---

# ACCM workbench

Mode: Operate. Native macOS 14+ with SwiftUI, AppKit and Ghostty. The user-authorized [ACCM direction](../../docs/accm-fidelity/DIRECTION.md) supersedes the earlier neutral grey visual direction. Preserve HerdrX identity, device connections and existing user preferences. This is source implementation against supplied native references, not a web composition or generated concept.

## Direction contract

THESIS: A compact Space workbench where task, state and device stay clear around real terminal output. Remove independent local Shells and their list/create entry points; retain ordinary sessions, detected Agents, tabs, splits and actions inside Spaces.

OWN-WORLD: The chosen family supplies workbench and terminal ground; semantic per-family app text remains separate from terminal ANSI colors. Offer Catppuccin, Tokyo Night, Gruvbox, One, Solarized, Kanagawa, Rosé Pine, Dracula, Nord and Vesper, plus HerdrX Default and Follow Herdr. System/light/dark and accent remain independent. Default resolves to Catppuccin; Follow Herdr reads local configuration without writing it. Dracula/Vesper light companions, Tokyo Day slate default/cursor/selection/ANSI 0/8 and Gruvbox Light/Rosé Pine Dawn dark ANSI 0 are HerdrX-authored adaptations. Native controls, system navigation type, SF Symbols and the purple slash identity remain.

STORY: Choose a device/Space, locate an Agent or ordinary terminal, then continue work through tabs and splits. Theme changes preserve mounted sessions and history. Creation, context menus and destructive actions retain their original object/device target. Users run Agent CLIs in the terminal; no dedicated launcher or file interface returns.

COLOR: `ThemeColors` derives foreground, secondary, accent and state roles against canvas, chrome, hover and the strongest sidebar/tab selection surfaces, targeting 4.5:1. Secondary begins with a 0.20 blend in both appearances and then receives contrast adjustment. Raw selection hue is distinct from adjusted accent text/focus/tint. Chromatic ANSI slots 1–6 and 9–14 receive hue-preserving shade adjustments against the canvas; those palette values also apply when used as backgrounds. The other slots retain source values except the named light adaptations. Ghostty minimum contrast is 1, faint opacity 0.85 and cursor text is mapped. Explicit indexed/RGB output and arbitrary foreground/background pairs are preserved; universal terminal readability is not claimed.

FIRST VIEWPORT: One 28pt integrated tab strip; 260pt default/reset sidebar with preserved saved width, resizable 200–480pt; 40pt action and footer rows. Space/Agent text aligns near 36pt from the window left. Two-line rows are approximately 45pt/51pt, with 13pt titles and 11pt metadata. Space uses light accent fill/outline; Agent uses stronger fill; trailing status stays visible. The first pane top outline sits approximately 42pt below the window top. Panes dominate the remaining space. Empty state chooses/creates a Space, not a standalone Shell.

FORM: Read the original 3840×2100 workbench reference at 2× Retina, not the viewer's resized preview. Preserve native points, baseline alignment and the pane title cutout. Settings uses six top icon tabs: Appearance, Terminal, Connections, Notifications, Tailcat, About. Content frames are 420×190pt for Appearance, 420×410pt for Terminal/About, 420×220pt for Notifications and 600×480pt for Connections/Tailcat, excluding OS chrome. Appearance controls start near 83pt with 7pt row/4pt inner gaps. Device popover rows carry name, connection source, status and selected checkmark.

UPDATES: About extends the existing grouped native form with automatic checks, optional automatic download/install, manual action, truthful status/last-check/failure detail and release notes. One app-lifetime Sparkle updater also serves the application-menu Check for Updates action. Checks default on every 24 hours while running; downloads default off and persist after opt-in. Background updates install on quit for Homebrew and direct installations; Herdr sessions keep running independently. Canceled checks/downloads clear progress and retain retry. The signed feed/archive release gate is separate from Apple notarization. Debug builds disable updates except the explicitly enabled isolated fixture. These changes remain local and unpublished.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

Keep [DESIGN.md](../../DESIGN.md) tokens and the [JSON sidecar](../design.json) current. No new raster assets ship in this iteration; existing icon provenance is retained. Current acceptance belongs in the [theme verdict](../../docs/theme-correction/VERDICT.md) and [updater verdict](../../docs/app-updates/VERDICT.md); the [ACCM finish review](../../docs/accm-fidelity/FINISH-REVIEW.md) preserves earlier geometry/action evidence. Native macOS is not a web detector target.

## Evidence boundary

The isolated fixtures label Agent names, states and illustrative output as synthetic; PTY, attach, RPC and terminal input are real. Earlier [native checks](../../docs/accm-fidelity/evidence/native-checks.json), [menu selection](../../docs/accm-fidelity/evidence/theme-menu.json) and [Space RPC counts](../../docs/accm-fidelity/evidence/space-actions-rpc.json) remain historical evidence. Current [theme validation](../../docs/theme-correction/VALIDATION.md) covers all ten families in both appearances, Default light, Follow Herdr dark, nine accents, hidden-pane restoration and before/after reattach. The compiled 3,600-pair check covers semantic foreground/secondary/accent colors against authored surfaces; it is not measured rendered-glyph certification. Corrected Gruvbox/Rosé Pine light captures come from a unique test bundle at 1200×760pt; earlier captures are 980×620pt. Reattach ANSI files match and terminal/pane IDs persist; neither independent PID verification nor a server replay fix is asserted.

[Updater validation](../../docs/app-updates/VALIDATION.md) records the signed 0.1.7 (9) → 0.1.8 (10) fixture manual install/relaunch, automatic background download/install on quit, preserved session content, canceled check/download recovery, invalid-feed rejection and up-to-date state. System mode is selectable and its native callback exists, but a macOS-driven appearance transition was not exercised. Arbitrary terminal color-pair readability, live Tailcat/SSH, notification permission/delivery, VoiceOver, IME, older macOS and English updater layout remain outside the completed checks. No pixel identity with ACCM, Apple notarization or public release of these changes is claimed.
