# HerdrX
<!-- impeccable:product-schema 1 -->

## Platform
Native macOS, 14.0 and later.

## Stack
SwiftUI and AppKit, libghostty, a small Foundation core, XcodeGen. User selected direct native implementation with running-app verification.

## Users and purpose
The supplied blueprint defines a workspace for developers managing local and remote terminal sessions and coding agents. The user confirmed an individual developer focus with a compact native sidebar, tabs, splits, task naming, automatic Agent status and reliable navigation.

## Constraints
Keep terminal byte traffic out of observable UI state. Preserve server sessions when the client detaches. Isolate device identities and named sessions. Reuse Herdr’s existing TOML plugin manifests and plugin.* APIs. Herdr owns extension execution and lifecycle; the GUI renders actions, logs and terminal panes. No separate plugin runtime or proprietary Schema protocol. ACC implementation is outside scope. Use simple names and a maintainable architecture derived from behavior, rather than mirroring the supplied tree.

The 2026-10-10 UX audit supersedes the earlier parity scope. Dedicated Agent launching, command override settings, file trees, previews, dual-ended transfer, attachment delivery and clipboard file/image interception are removed. Users launch CLI tools directly in terminal panes. Preserve text copy/paste, automatic Agent recognition, state and navigation, connection management, search and generic Herdr plugin compatibility. Do not delete user files or obsolete preference storage as part of removing their consumers. This scope is recorded in [docs/ux-audit/SCOPE.md](docs/ux-audit/SCOPE.md).

The later [ACCM direction](docs/accm-fidelity/DIRECTION.md) replaces the neutral grey visual direction with the user's supplied native references. Remove independent client-owned local Shells, their sidebar groups and creation entry points. Preserve Herdr-backed Space sessions, ordinary terminal panes, detected Agents, tabs, splits and their actions on local and remote devices. Launching the app does not create a standalone local Shell; the user connects to Herdr and chooses or creates a Space. Terminal settings remain because those Spaces use real Ghostty terminals.

Provide ten switchable palette families (Catppuccin, Tokyo Night, Gruvbox, One, Solarized, Kanagawa, Rosé Pine, Dracula, Nord and Vesper), plus HerdrX Default and Follow Herdr. System/light/dark appearance and accent choice are independent preferences. Default currently resolves to Catppuccin. Follow Herdr reads the local configuration without changing it. Theme changes preserve mounted sessions and terminal history. Settings uses six native toolbar tabs: Appearance, Terminal, Connections, Notifications, Tailcat and About. Existing user preferences remain authoritative; the font default is Maple Mono CN when installed, otherwise SF Mono, at 13.5pt.

Current evidence lives in [docs/accm-fidelity/evidence/native-checks.json](docs/accm-fidelity/evidence/native-checks.json), the neighboring test records and [finish review](docs/accm-fidelity/FINISH-REVIEW.md). Agent names, state and illustrative output in the isolated fixture are synthetic; PTY, attach, Space creation, tabs and splits are real. The visually inspected families are Catppuccin light and Tokyo Night dark. Menu selection of other families is not a visual certification. Live Tailcat, SSH, notification permission/delivery, VoiceOver, IME and older macOS remain unverified in this pass. This work establishes neither pixel identity with ACCM nor a new release.

## Brand commitments
HerdrX. Simple, recognizable icon, inspired by Ghostty's clarity with original artwork and native macOS packaging. Distribution primarily uses cleanwk/homebrew-tap, with GitHub Actions release packaging.
