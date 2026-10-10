disposition: fix

Historical finding: the cancellation fix was subsequently scored resolved; see the [verdict pass](VERDICT.md) (`disposition: ship` at the material-fix scope).

Fresh native updater review, 2026-10-10. Scope: the requested automatic checks, automatic updates and manual updates. Theme work is outside this review. This is a SwiftUI/AppKit/Sparkle extension to the existing Operate surface; no web detector ran. No approved comp, comp-diff or separate QUALITY BAR card applies. The reviewer inspected source, opened the supplied native capture and ran the Python release tests; the reviewer did not operate the app or publish a release.

## persistence

`DESIGN.md` and `.impeccable/surfaces/app-workbench-swift.md` establish the compact native workbench, system typography and six-tab settings. The updater inherits that world. The new lifetime-owned `AppUpdater`, persisted Sparkle settings and app-menu command replace the previous About-owned controller and Homebrew-command presentation.

The planned documenter must reflect this extension in `PRODUCT.md`, `DESIGN.md`, the surface brief and `.impeccable/design.json`; the sidecar currently describes the old Homebrew command/direct-update eligibility rows. Preserve the distinction between Sparkle Ed25519 verification and Apple Developer ID/notarization, and state that no release of these changes has been published.

The supplied [settings capture](evidence/settings.png) is valid: 840 × 996 pixels, a complete Chinese About view at 2×, with the automatic-check and automatic-install controls, current version, discovered version, check time and manual action legible and unclipped. Its purple capture badge and pointer overlay are not product chrome.

## fidelity

| Promise | Verdict | Evidence and limits |
| --- | --- | --- |
| Automatic detection without opening About | match | `Main.swift` owns one `@StateObject AppUpdater` and starts it from the main workbench task. `start()` is guarded against repeated initialization. The parent reports an automatic check before About was opened. |
| Persistent automatic-check preference | match | Settings writes Sparkle's `automaticallyChecksForUpdates` property; published KVO values drive the UI. No launch-time setter overwrites the saved preference. The bundle's initial setting enables checks with an 86,400-second interval. |
| Opt-in automatic download/install | match at source scope | The bundle defaults automatic downloads off. The second toggle writes `automaticallyDownloadsUpdates`; its enabled state follows `allowsAutomaticUpdates`, including the dependency on automatic checks. Returning `false` from `willInstallUpdateOnQuit` leaves Sparkle's scheduler in control. Parent runtime verification was still pending when this review began. |
| Manual update access | match | About presents Check for Updates / View and Install Update, and the application menu has Check for Updates. Both use the lifetime-owned controller and its `canCheckForUpdates` readiness. The parent reports a local signed fixture upgrade from 0.1.7 (9) to 0.1.8 (10), installation and relaunch, with resulting plist and deep code-signature checks. This is reported fixture evidence, not a public-release claim. |
| Truthful progress and cancellation | contradicted in the initial implementation | Cancelling the initial check or download finishes Sparkle's cycle with a nil error. The original `didFinishUpdateCycleFor` immediately returned on nil; download cancellation's separate delegate callback was missing. About could remain on “Checking…” or “Downloading…” after cancellation. See material fix 1. |
| Native hierarchy and Chinese content | match | Existing native grouped settings, system type, switch controls and action buttons are retained. Automatic checks, background installation and manual action are adjacent and understandable. Chinese labels and helper copy fit the complete capture. No redesign or decorative material is needed. |
| Signed feed and archive trust | match at reviewed pipeline scope | The pinned Sparkle 2.9.6 bundle requires a signed feed and pre-extraction verification. The CI generator compares the archived app's public key with its signing key before signing; `appcast.py` then validates the configured/bundle key, exact version, minimum OS, URL, length, SHA-256 and signature shape, and invokes Sparkle's official verification for feed and archive. The parent reports rejection of a tampered feed. |
| Homebrew self-update declaration | match | `distribution/tap/update.py` only adds `auto_updates true` when metadata explicitly reports verified signed updates and the release's versioned appcast asset digest matches. Existing notarization caveat remains independent. |
| Release contract tests | match | Reviewer ran `python3 -m unittest discover -s scripts -p 'test_*py'`: six tests passed. This covers metadata rejection paths and cask generation, not a real GitHub Actions publication. |

## ceiling

The updater's quality bar is predictable native operation and accurate state. The existing composition meets that bar in the supplied Chinese About capture. Do not add custom progress chrome, illustrations or motion. Native system controls, compact copy and semantic action names are appropriate. English layout, VoiceOver, keyboard focus traversal, disabled controls and older macOS were not independently demonstrated by the supplied capture. Automatic download/quit-install, no-update and failure evidence was being collected by the parent; do not infer these passes from the settings image alone.

## material_fixes

1. **Truthful cancellation state.** Handle Sparkle's `userDidCancelDownload` callback and the nil-error cycle finish when an initial manual check is canceled. Clear progress and show a retryable canceled state. Preserve valid nil-error completions such as a discovered update or a ready-on-quit update. Verify both a canceled initial check and a canceled in-progress download, then recapture the resulting About state. Source evidence: the pinned `SPUUIBasedUpdateDriver.m:348–355` invokes `userDidCancelDownload` then aborts with nil; `SPUUserInitiatedUpdateDriver.m:129–132` also aborts with nil. The implementation thread added the two handlers during review; final evidence and the verdict pass remain required.

## keep

Keep the single app-lifetime updater, persisted native Sparkle preferences, default-off background installation, install-on-quit behavior, app-menu and About manual entry points, signed feed plus pre-extraction verification, exact artifact metadata checks, localized recovery copy and explicit separation of Ed25519 signing from Apple notarization. Preserve existing Herdr sessions and the established native settings hierarchy.
