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

The later 2026-10-10 UX audit supersedes the earlier parity scope. Remove dedicated Agent launching, command override settings, file trees, previews, dual-ended transfer, attachment delivery and clipboard file/image interception. Users launch CLI tools directly in terminal panes. Preserve text copy/paste, automatic Agent recognition, state and navigation, connection management, search and generic Herdr plugin compatibility. Do not delete user files or obsolete preference storage as part of removing their consumers. The user's clarification and current acceptance evidence live in docs/ux-audit/SCOPE.md and RESULTS.md. Tailcat, native input and unavailable environment checks must be reported honestly.

## Brand commitments
HerdrX. Simple, recognizable icon, inspired by Ghostty's clarity with original artwork and native macOS packaging. Distribution primarily uses cleanwk/homebrew-tap, with GitHub Actions release packaging.
