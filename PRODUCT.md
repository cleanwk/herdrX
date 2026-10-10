# HerdrX
<!-- impeccable:product-schema 1 -->

## Platform
Native macOS, 14.0 and later.

## Stack
SwiftUI and AppKit, libghostty, a small Foundation core, XcodeGen. User selected direct native implementation with running-app verification.

## Users and purpose
The supplied blueprint defines a workspace for developers managing local and remote terminal sessions and coding agents. The user confirmed the individual developer focus and the native sidebar, tabs, splits without a file browser or preview.

## Constraints
Keep terminal byte traffic out of observable UI state. Preserve server sessions when the client detaches. Isolate device identities and named sessions. Reuse Herdr’s existing TOML plugin manifests and plugin.* APIs. Herdr owns extension execution and lifecycle; the GUI renders actions, logs and terminal panes. No separate plugin runtime or proprietary Schema protocol. ACC implementation is outside scope. Use simple names and a maintainable architecture derived from behavior, rather than mirroring the supplied tree.

The latest user instruction removes built-in file trees, directory browsing, file previews and the independent file window. Keep the host focused on terminal work and Herdr extensions.

## Brand commitments
HerdrX. Simple, recognizable icon, inspired by Ghostty's clarity with original artwork and native macOS packaging. Distribution primarily uses cleanwk/homebrew-tap, with GitHub Actions release packaging.
