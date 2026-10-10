---
version: 1
slug: "app-workbench-swift"
primary_target: "App/Workbench.swift"
related_targets: ["App/Terminal.swift","App/Sidebar.swift","App/Tabs.swift","App/Preferences.swift","App/PreferenceMenu.swift","App/Theme.swift","App/DeviceSwitcher.swift"]
---

# ACCM workbench

Mode: Operate. Native macOS 14+ with SwiftUI, AppKit and Ghostty. The user-authorized [ACCM direction](../../docs/accm-fidelity/DIRECTION.md) supersedes the earlier neutral grey visual direction. Preserve HerdrX identity, device connections and existing user preferences. This is source implementation against supplied native references, not a web composition or generated concept.

## Direction contract

THESIS: A compact Space workbench where task, state and device stay clear around real terminal output. Remove independent local Shells and their list/create entry points; retain ordinary sessions, detected Agents, tabs, splits and actions inside Spaces.

OWN-WORLD: The chosen palette colors workbench and terminal together. Offer Catppuccin, Tokyo Night, Gruvbox, One, Solarized, Kanagawa, Rosé Pine, Dracula, Nord and Vesper, plus HerdrX Default and Follow Herdr. System/light/dark and accent remain independent. Default resolves to Catppuccin; Follow Herdr reads local configuration without writing it. Dracula/Vesper light companions are HerdrX-authored. Native controls, system navigation type, SF Symbols and the purple slash identity remain.

STORY: Choose a device/Space, locate an Agent or ordinary terminal, then continue work through tabs and splits. Theme changes preserve mounted sessions and history. Creation, context menus and destructive actions retain their original object/device target. Users run Agent CLIs in the terminal; no dedicated launcher or file interface returns.

FIRST VIEWPORT: One 28pt integrated tab strip; 260pt default/reset sidebar with preserved saved width, resizable 200–480pt; 40pt action and footer rows. Space/Agent text aligns near 36pt from the window left. Two-line rows are approximately 45pt/51pt, with 13pt titles and 11pt metadata. Space uses light accent fill/outline; Agent uses stronger fill; trailing status stays visible. The first pane top outline sits approximately 42pt below the window top. Panes dominate the remaining space. Empty state chooses/creates a Space, not a standalone Shell.

FORM: Read the original 3840×2100 workbench reference at 2× Retina, not the viewer's resized preview. Preserve native points, baseline alignment and the pane title cutout. Settings uses six top icon tabs: Appearance, Terminal, Connections, Notifications, Tailcat, About. Content frames are 420×190pt for Appearance, 420×410pt for Terminal/About, 420×220pt for Notifications and 600×480pt for Connections/Tailcat, excluding OS chrome. Appearance controls start near 83pt with 7pt row/4pt inner gaps. Device popover rows carry name, connection source, status and selected checkmark.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

Keep [DESIGN.md](../../DESIGN.md) tokens and the [JSON sidecar](../design.json) current. No new raster assets ship in this iteration; existing icon provenance is retained. Acceptance and any remaining fixes belong in the [finish review](../../docs/accm-fidelity/FINISH-REVIEW.md). Native macOS is not a web detector target.

## Evidence boundary

The isolated `herdrx-fidelity-20261010` fixture labels Agent names, states and illustrative output as synthetic. PTY, attach, Space/tab/split RPC and terminal input are real. [Native checks](../../docs/accm-fidelity/evidence/native-checks.json), [menu selection](../../docs/accm-fidelity/evidence/theme-menu.json), [Space RPC counts](../../docs/accm-fidelity/evidence/space-actions-rpc.json), test records and [screenshots](../../docs/accm-fidelity/screenshots) preserve the evidence. Catppuccin light and Tokyo Night dark are the only visually inspected families; selecting the other ten menu choices establishes binding, not complete visual quality. Tailcat, SSH, notification permission/delivery, VoiceOver, IME, old macOS and every palette/accent contrast remain unverified in this pass. Neither pixel identity with ACCM nor a new release is claimed.
