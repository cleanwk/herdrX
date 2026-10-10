# App update validation

Recorded 2026-10-10. The updater extends the existing native macOS settings world. Its source is `App/Updater.swift`, `App/Main.swift`, `App/Preferences.swift`, `App/Info.plist` and `project.yml`, with release checks in `.github/workflows/release.yml`, `scripts/appcast.py` and `distribution/tap/update.py`. [DESIGN.md](../../DESIGN.md), the [sidecar](../../.impeccable/design.json) and [surface brief](../../.impeccable/surfaces/app-workbench-swift.md) now document the new About behavior. No web detector applies.

## Implemented behavior

One app-lifetime Sparkle 2.9.6 updater starts from the main window and serves both the app-menu Check for Updates command and About. Automatic checks default on, every 86,400 seconds while the app runs. Automatic download/install defaults off; Sparkle-backed controls preserve the user's choices. Enabling background downloads permits installation on quit, with Herdr sessions continuing independently. Homebrew and direct installations share this updater.

About retains the native grouped form and 420×410pt content frame, excluding OS titlebar/toolbar. It shows version/project, the two automatic options, localized status, last check, failure details, manual action, release notes and notices. Pending checks show a native spinner. Check/download cancellation clears progress and leaves retry available; a valid ready-on-quit state remains distinct. Debug builds disable updates unless explicitly enabled for the isolated fixture, whose localhost feed override is unavailable to release builds.

## Evidence

| Check | Recorded result and boundary |
| --- | --- |
| Automatic-check and download defaults | Bundle configuration enables automatic checks and disables automatic downloads. The implementation thread reports confirming initial values and persisted opt-in; the [ready capture](evidence/automatic-ready.png) and [AX](evidence/automatic-ready-ax.txt) show both options enabled after opt-in. This record does not mistake that opted-in state for the default. |
| Manual signed update | [install-result.json](evidence/install-result.json) records an isolated signed fixture upgrade from 0.1.7 (9) to 0.1.8 (10), install/relaunch and deep code-signature verification. |
| Automatic download and quit-install | The same installation record passes background download/install on quit. The implementation thread reports no manual check initiating that download; [automatic-ready.png](evidence/automatic-ready.png) shows the ready-on-quit message and the available manual action. |
| Session continuity | The installation record reports preserved persistent session content/SGR; viewport resizing changed wrapping only. The [post-automatic-update ANSI record](../theme-correction/evidence/fixture-after-auto-update.ansi) preserves the fixture content for inspection. |
| Cancel initial manual check | [Capture](evidence/check-canceled.png) and [AX](evidence/check-canceled-ax.txt) show the canceled message, no spinner and an enabled Check for Updates action. The reviewer scored the cancellation fix resolved. |
| Cancel in-progress download | [Capture](evidence/download-canceled.png) and [AX](evidence/download-canceled-ax.txt) show a retryable canceled state and enabled View and Install action. The reviewer scored this fix resolved. |
| Reject invalid signed feed | [Native Sparkle alert](evidence/invalid-signature.png) shows rejection by the running fixture client. [Failure AX](evidence/update-failed-ax.txt) records matching About failure details and enabled retry; this goes beyond a command-line signature test. |
| Already up to date | [Capture](evidence/up-to-date.png) and [AX](evidence/up-to-date-ax.txt), added after the updater verdict, show version 0.1.8 (10), the up-to-date message and enabled Check for Updates action. The implementation thread reports testing that version against the valid signed feed for the same version. Automatic checks are off in this capture and the dependent download toggle is disabled. |
| Native layout | Complete Chinese About captures are 840×996 pixels at 2×. The settings, ready, cancellation, failure and up-to-date evidence preserves system controls and readable copy. Purple capture badges and highlighted pointers are tooling overlays, not product chrome. |
| Release contract tests | The [initial review](FINISH-REVIEW.md) records six passing Python release tests. The final universal Release build passed the 20 Core tests, deep signature and architecture checks. The implementation thread then packaged that app, generated its signed appcast and passed `scripts/appcast.py` with the official Sparkle verifiers, producing `signed_updates: true` in local fixture metadata. This used the unchanged 0.1.7 version for a local pipeline check only. These checks do not establish a real GitHub Actions release. |

## Acceptance and limits

The [verdict](VERDICT.md) is `ship` at the single cancellation material-fix scope. It is not a new whole-app audit or authorization to publish. That verdict read the installation record and opened the cancellation, automatic-ready and invalid-signature captures; it did not repeat installation. The later up-to-date evidence completes the implementation thread's pending runtime branch. The documenter read source/records and opened automatic-ready and up-to-date captures without operating the app or repeating installation.

Sparkle Ed25519 feed/archive trust is distinct from Apple Developer ID signing and notarization. The fixture's deep signature check does not establish Apple notarization. Real GitHub release publication, English updater layout, full keyboard traversal, VoiceOver and older macOS remain unverified here. Homebrew `auto_updates true` is gated by verified signed-update metadata and the versioned appcast asset digest; this is a distribution contract, not proof of a separately exercised Homebrew upgrade. All changes are local and unpublished.
