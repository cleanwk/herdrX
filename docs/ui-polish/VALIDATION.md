# Native UI refinement — 2026-10-10

Status: implementation and automated checks complete; the user requested PR merge and a local app update, with visual acceptance performed by the user. No public release is part of this change.

## Evidence and scope

The initial running installed app was inspected with native Computer Use, including its current split workspace. Source and existing committed native captures informed two independent reviews: settings/design and performance. The user's subsequent sidebar and tab screenshots set the follow-up reference for tool icons and scrolling. No web detector applies to this SwiftUI/AppKit macOS application. The context launcher's unsupported native-macOS platform warning was reported; PRODUCT.md was not misclassified as web.

## Implemented

- Tab strip: shared 34pt host/document height, 24pt tabs, 5pt vertical clearance, 6pt horizontal inset and inter-tab gap. Drag insertion marker sits in the gap. Selected text is semibold and inactive text regular; reorder/context actions stay intact.
- Panes: 10pt outer bottom radius on all supported macOS versions; sidebar-open left edge and internal split corners remain square, sidebar-hidden outer left edge rounds, full-screen edges stay square. The opaque terminal layer follows the same bottom-corner decisions so it cannot paint over the border.
- Pane controls: stable 22pt target, 9pt close glyph, aligned title/control cutouts, hover and pressed backgrounds; focused pane keeps its close action visible. Terminal content is clear of the controls. PaneMetrics shares content geometry with minimum-size validation.
- Settings: English segmented controls fit their intrinsic widths, accent layout wraps as a group when needed, Appearance/Terminal scroll, About helper text aligns with switches, Notifications uses available width, native menu selection uses stable IDs. Details and targeted AppKit validation are in SETTINGS.md.
- Agent identity: nine bundled vector template marks (including agy/Antigravity), a shared sidebar/search component, semantic theme tint and native fallback for unknown tools. Sources and hashes: Resources/Icon/AgentIcons.json; MIT license included in app notices.
- Sidebar: its native scroller uses small overlay styling and automatic hiding without a reserved legacy gutter. macOS global preferences are unchanged.
- Performance: bounded semantic-color cache, indexed status/group lookups, and no identical derived-state publications. Measured results and exact equivalence boundaries are in PERFORMANCE.md. Tab pane counts now use one pass; close-button visibility uses the current visible-key set; identical terminal frames are not reassigned. These latter changes are source-level improvements, not separate timing claims.

## Checks completed

- Final Xcode Debug build succeeded, including the new asset catalog; only AppIntents metadata extraction warning (no dependency) appeared. Local full log: build/ui-polish/final-build.log.
- Core release tests: 20 passed, zero failures; evidence/core-tests.txt.
- Compiled Assets.car contains all nine agent-* assets.
- Settings native popup harness passed duplicate-title identity, reorder, separator and stable-instance checks (SETTINGS.md).
- Performance harness passed 486 exact color comparisons and status/recency/branch/device-ID/removal index equivalence cases. At 1,000 synthetic panes, final local reindex median was 1,547.174 → 11.993ms; this is not application frame-time certification.
- git diff --check and design sidecar JSON validation passed.

## Pending visual acceptance

Computer Use rejected access to the isolated app with `Computer Use was not approved to use HerdrX`. The user explicitly authorized continuing; a retry returned the same tool-level refusal. No alternate screen/AX automation was used to bypass it. Therefore no final running-app screenshot or interaction is claimed. Earlier captures establish the incumbent only, not the new geometry.

The isolated test build was run from `build/ui-polish/HerdrX UI.app` with bundle ID `io.github.cleanwk.herdrx.polish.ui`, 1200×760pt window, separate app preferences and `build/ui-polish/state`. It connects only to the disposable `herdrx-polish-20261010` named Herdr session plus a deliberately unavailable socket. It was used only for the isolated test attempt. The user subsequently requested updating the installed app and taking over visual acceptance.

User acceptance checklist: 1200×760 and 980×620 windows; light/dark; sidebar expanded/collapsed; multiple tabs and tab overflow; horizontal/vertical splits, zoom and close hover; long Agent list with tool icons and scrolling; Search/New Space/device chooser; all six settings tabs including English Appearance, 22pt Terminal preview, Connections/Plugins, Notifications, Tailcat and About. Fix any material findings together, confirm once, then stop. Avoid interacting with real user panes or generating Tailcat identities.

Live SSH/Tailcat, notification delivery, updater installation, VoiceOver, IME, older macOS and all-theme pixel certification are outside completed validation. No claim of completed visual acceptance or full reference fidelity is made.

To end the disposable session after acceptance: quit the isolated test app and run `herdr --session herdrx-polish-20261010 server stop`. This command targets only the session created for this review.
