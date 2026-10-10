# HerdrX
<!-- impeccable:product-schema 1 -->

## Platform
Native macOS, 14.0 and later.

## Stack
SwiftUI and AppKit, libghostty, a small Foundation core, XcodeGen. User selected direct native implementation with running-app verification.

## Users and purpose
The supplied blueprint defines a workspace for developers managing local and remote terminal sessions and coding agents. The user confirmed the individual developer focus and the compact native sidebar, tabs, splits, on-demand read-only files and single-file transfer.

## Constraints
Keep terminal byte traffic out of observable UI state. Preserve server sessions when the client detaches. Isolate device identities and named sessions. Reuse Herdr’s existing TOML plugin manifests and plugin.* APIs. Herdr owns extension execution and lifecycle; the GUI renders actions, logs and terminal panes. No separate plugin runtime or proprietary Schema protocol. ACC implementation is outside scope. Use simple names and a maintainable architecture derived from behavior, rather than mirroring the supplied tree.

The 2026-10-10 parity specification adds lazy file trees, read-only text/image previews (2 MiB), and a two-ended single-file transfer view for local and SSH devices. Tailcat transport, full settings and input behavior remain in the requested scope; incomplete work must be tracked explicitly in docs/parity/STATUS.md. Retain HerdrX identity and native Herdr plugins. Exclude ACC business integrations only.

## Brand commitments
HerdrX. Simple, recognizable icon, inspired by Ghostty's clarity with original artwork and native macOS packaging. Distribution primarily uses cleanwk/homebrew-tap, with GitHub Actions release packaging.
