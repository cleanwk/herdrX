# HerdrX
<!-- impeccable:product-schema 1 -->

## Platform
Native macOS, 14.0 and later.

## Stack
SwiftUI and AppKit, libghostty, a small Foundation core, XcodeGen. User selected direct native implementation with running-app verification.

## Users and purpose
The supplied blueprint defines a workspace for developers managing local and remote terminal sessions and coding agents. The user confirmed an individual developer focus with a compact native sidebar, tabs, splits, task naming, automatic Agent status and reliable navigation.

## Constraints
HerdrX is a GUI for Herdr. Reuse existing Herdr capabilities and RPCs; keep session identity, tab names, pane lifecycle and layout authoritative on the server. Add only the UI state needed to present and safely invoke those capabilities, without parallel client-owned domain features.

Keep terminal byte traffic out of observable UI state. Preserve server sessions when the client detaches. Isolate device identities and named sessions. Reuse Herdr’s existing TOML plugin manifests and plugin.* APIs. Herdr owns extension execution and lifecycle; the GUI renders actions, logs and terminal panes. No separate plugin runtime or proprietary Schema protocol. ACC implementation is outside scope. Use simple names and a maintainable architecture derived from behavior, rather than mirroring the supplied tree.

The 2026-10-10 UX audit supersedes the earlier parity scope. Dedicated Agent launching, command override settings, file trees, previews, dual-ended transfer, attachment delivery and clipboard file/image interception are removed. Users launch CLI tools directly in terminal panes. Preserve text copy/paste, automatic Agent recognition, state and navigation, connection management, search and generic Herdr plugin compatibility. Do not delete user files or obsolete preference storage as part of removing their consumers. This scope is recorded in [docs/ux-audit/SCOPE.md](docs/ux-audit/SCOPE.md).

The later [ACCM direction](docs/accm-fidelity/DIRECTION.md) replaces the neutral grey visual direction with the user's supplied native references. Remove independent client-owned local Shells, their sidebar groups and creation entry points. Preserve Herdr-backed Space sessions, ordinary terminal panes, detected Agents, tabs, splits and their actions on local and remote devices. Launching the app does not create a standalone local Shell; the user connects to Herdr and chooses or creates a Space. Terminal settings remain because those Spaces use real Ghostty terminals.

Provide ten switchable palette families (Catppuccin, Tokyo Night, Gruvbox, One, Solarized, Kanagawa, Rosé Pine, Dracula, Nord and Vesper), plus HerdrX Default and Follow Herdr. System/light/dark appearance and accent choice are independent preferences. Default currently resolves to Catppuccin. Local Herdr theme reads only the local theme family without changing it; custom colors and remote theme settings are not synced. Theme changes preserve mounted sessions and terminal history. Settings uses six native toolbar tabs: Appearance, Terminal, Connections, Notifications, Tailcat and About. Existing user preferences remain authoritative; the font default is Maple Mono CN when installed, otherwise SF Mono, at 13.5pt.

Interaction evidence lives in [docs/accm-fidelity/evidence/native-checks.json](docs/accm-fidelity/evidence/native-checks.json) and the neighboring review records. The subsequent [theme validation](docs/theme-correction/VALIDATION.md) covers all ten families in light and dark, Default, Follow Herdr and nine independent accents. Navigation uses semantic text roles; terminal ANSI adaptations are bounded and do not certify arbitrary application foreground/background pairs. Agent names, state and illustrative output in the isolated fixture are synthetic; PTY, attach, Space creation, tabs and splits are real. Live Tailcat, SSH, notification permission/delivery, VoiceOver, IME, an OS-driven appearance transition and older macOS remain outside this UI pass. This work establishes neither pixel identity with ACCM nor a new release.

The 0.1.8 [app updater](docs/app-updates/VALIDATION.md) provides automatic checks, optional background download/install on quit, and manual checks from the app menu and About. Signed feed and archive verification precede installation. Automatic checks default on; automatic downloads default off.

Local connection recovery can invoke Herdr’s existing headless server command on explicit user request for a recognized default or named session. It provides presentation, readiness checks and failure recovery, not a new session protocol, automatic service supervisor or installation system. Custom sockets and remote server lifecycle remain configured in Herdr. See [connection recovery validation](docs/connection-recovery/VALIDATION.md).

## Brand commitments
HerdrX. Simple, recognizable icon, inspired by Ghostty's clarity with original artwork and native macOS packaging. Distribution primarily uses cleanwk/homebrew-tap, with GitHub Actions release packaging.
