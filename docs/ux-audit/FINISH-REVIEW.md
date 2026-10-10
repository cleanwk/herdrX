disposition: fix

# HerdrX native workbench finish review — 2026-10-10

## 1. Scope and evidence

Fresh, read-only finish review of the current native SwiftUI/AppKit workbench. The controlling brief is [SPEC.md](SPEC.md), overridden by [SCOPE.md](SCOPE.md), with the direction in [app-workbench-swift.md](../../.impeccable/surfaces/app-workbench-swift.md). All Agent launcher, file tree, preview, transfer and attachment delivery features are outside the retained product. This is refinement of the user's wireframe, with no approved image comp or replacement visual world. A concept seed and image reproduction gate do not apply.

Opened and inspected all seven required captures: [light, 980/200](screenshots/workbench-light-980-200.png), [light, 980/260](screenshots/workbench-light-980-260.png), [dark, 1440/480](screenshots/workbench-dark-1440-480.png), [empty search](screenshots/search-empty-light.png), [search results](screenshots/after-search-light.png), [About & Updates](screenshots/about-updates.png), and [server close confirmation](screenshots/server-close-confirm.png). They show the named states, with rendered terminal content and coherent window/sheet boundaries. The workbench images use Retina pixels; point dimensions govern the contract. The system capture indicator covers the traffic-light region, so these images cannot assess the window-control glyphs themselves. This does not invalidate the reviewed content regions.

Sampled `App/Workbench.swift`, `Sidebar.swift`, `Tabs.swift`, `Terminal.swift`, `Navigation.swift`, `SearchInput.swift`, `Theme.swift`, and `Preferences.swift`. Reviewed the supplied AX, search-keyboard, target/cancel, surface-reuse and performance evidence. The last minor focus/neighbor/localization edits postdate some captures; their visual claims are not substituted for screenshots. No UI was controlled, no app was rendered, and no code was edited by this reviewer.

Native platform conventions and the craft floor govern this pass. The iOS reference was interpreted for macOS: compact desktop controls and point sizes are not scored against phone touch targets. No HTML/CSS detector ran or applies. `PRODUCT.md` exists and records the new scope; the context loader warns that its literal platform value is unrecognized, but the implementation and review are explicitly native macOS. The existing `DESIGN.md` is stale (finding F2).

## 2. Direction and fidelity assessment

| Element / contract promise | Assessment | Evidence |
| --- | --- | --- |
| THESIS: quiet terminal workbench, task/device clarity | Match at the reviewed scope | Terminal owns the detail region. Task-first Agent titles agree with the active pane and close confirmation. Device/session context is present in pane subtitles, search and AX/help. Narrow rows truncate with full context available in help. |
| OWN-WORLD: native controls, neutral chrome, distinct selection/focus/state | Match except F1 | SwiftUI/AppKit controls and SF Symbols remain native. Primary chrome is neutral; blue selection and pane focus are distinct from orange blocked state. The latter's text contrast is insufficient in light appearance. |
| STORY: find, inspect, return to the correct object | Supported, with runtime limits | Search keyboard evidence keeps focus in the input while selection moves. Target/cancel evidence reports creation only on B and no server pane closure after cancellation. Source validates search targets and binds object actions by identity. This does not prove the full native interaction matrix. |
| FIRST VIEWPORT: 28pt tab strip, default 260pt sidebar, 40pt head/footer | Match | `Workbench.swift:15–42`; the 200/260/480 captures preserve the single strip and fixed sidebar action/filter regions. Terminal panes occupy the removed file region. |
| FORM: preserve measured compact native layout | Match | No new decorative scaffolding, extra toolbar, launcher or file surface appears. The four-section settings navigation follows the accepted consolidation. |
| TYPE | Match in character/hierarchy; readability exception F1 | Native system navigation, 13.5pt task names, 11pt status/context, compact system-mono pane titles and actual terminal text. Text-led hierarchy is retained; no foreign display face. |
| MATERIAL | Match | Native grouped forms, sheets, alert, separators and terminal canvas. No imitation physical material, ornamental blur or website-shaped card system. |
| GROUND | Match to source-defined theme surfaces | Light neutral chrome and white terminal; dark neutral chrome and darker terminal. The contract pins semantic/theme-aware surfaces rather than an independently sampled color comp. |
| Product subtraction | Match in reviewed UI and primary consumers | Main controls are New Space, Search, New Terminal Tab and Pane Layout. Settings has Appearance, Terminal, Connections, About & Updates. No removed feature reappears in the inspected surfaces. |
| Persistence | Incomplete | PRODUCT and the surface contract describe current scope; DESIGN still documents removed consumers and previous layout behavior. |

The native quality bar is reached in hierarchy, density and restraint. No unused decoration, motion treatment or alternative composition is needed. Readability and documentation are the remaining material gaps.

## 3. Material findings and requested fixes

1. **F1 · P2 · Small state and active-pane text use unchecked accent colors.** In [workbench-light-980-260.png](screenshots/workbench-light-980-260.png), the selected Agent's 11pt “等待输入” is bright orange on the pale blue selection. The 200pt capture shows the same treatment. `Sidebar.swift:64` returns raw `.orange`, and `Workbench.swift:137–138` applies it directly to small status text. Rendered-pixel sampling of the 260pt capture's status area (x392–485, y995–1022, Retina pixels) gives approximately **1.7–2.0:1** against the local selected-row ground. Compression/antialiasing makes this an approximate rendered measurement, but the shortfall is substantial and agrees with the source. This obscures a state the user explicitly required to remain readable. The same unchecked-color path exists in the 11pt active pane title (`Terminal.swift:192`): it uses `Theme.accent`, which explicitly permits amber/systemYellow and orange (`Theme.swift:14–16`). Those accent settings are not represented by the required captures, so this is a source-confirmed exposure rather than an invented claim that an amber screenshot was tested. **Fix:** use native labelColor for the status word and pane main title, keeping saturated state color on the dot/shape, and keeping active pane emphasis in semibold weight plus its accent border. Confirm at least 4.5:1 for the 11pt labels in the light selected state, and verify the unchanged dark state. User-selectable accents must not become unchecked small-text colors. This is one shared craft-floor and UX02/UX19 readability fix, not a palette redesign.

2. **F2 · P2 · Existing DESIGN.md contradicts the product being shipped.** It still describes on-demand file browsing, file-manager geometry, Agent creation, nine settings categories and a fixed 320pt empty search viewport. Those claims conflict with SCOPE and the reviewed implementation (`Workbench.swift:188–224`, `Preferences.swift:11`). **Fix:** refresh the source-observed design document as planned, removing obsolete product/component descriptions and recording the current four-section settings, content-sized search and neutral chrome. Keep historical acceptance claims separate from current evidence. Do not reintroduce removed features to satisfy the old document.

No rebuild or new feature is requested. Apply the two bounded fixes and return the relevant updated light/dark captures plus refreshed documentation for a verdict pass over F1–F2.

## 4. Quality checks and limitations

- **Native structure and adaptivity:** supplied minimum-width light views and larger dark view retain readable primary labels, clear terminal focus, stable sidebar head/footer and no file-panel residue. The search empty state contracts to its content. Long search and pane context intentionally truncates with full help/AX content.
- **Interaction and accessibility:** source separates explicit focus requests from layout, uses AppKit text editing with a marked-text guard, labels tab roles/state and splitter adjustments, and keeps status words alongside glyphs. The supplied AX samples expose full object context. AX trees and source are not VoiceOver or IME operational passes.
- **Lifecycle:** supplied surface evidence reports 24 server surfaces plus one local shell, no surface-identity changes and no hidden frame/resize changes across its observations. The packet reports 19 core tests and passing PTY restart/foreground activity tests. These establish their named code/runtime checks only.
- **Performance:** before/after tool-driven search/scroll samples exist. They include automation/observation latency; neither those samples nor pure search timings establish native frame pacing or an unconditional “smooth” verdict. No such claim is made here.
- **Still unverified:** full IME composition/candidate placement, VoiceOver traversal and activation, keyboard full access/increased contrast, remote SSH failure/recovery, Tailcat, full theme/accent/font matrix, and every C01–C90 runtime scenario. The supplied evidence does not justify marking these PASS. Removed C86–C90 remain REMOVED_BY_SCOPE.
- **Craft floor:** no arbitrary decorative cards, gradient lettering, fake physicality, mixed icon system or unnecessary new modality was found. Deliberate native sheets and close confirmation fit their tasks. F1 prevents a blanket contrast pass; secondary text and user accent combinations still need their declared matrix coverage.

## 5. Disposition

**fix** — the captured workbench preserves the agreed native direction; unchecked small-text accent colors and stale design documentation remain material, bounded fixes. This is not approval of unrun native acceptance cases.

Keep the task-first two-line Agent rows, neutral primary controls, 28pt integrated strip, explicit device/session identity, native text controls, compact settings, and the complete removal of file/attachment/launcher UI while fixing.

---

## Post-fix verdict — 2026-10-10

- **F1 — resolved.** Reopened the same three recaptured workbench paths: light 980/200, light 980/260 and dark 1440/480. All are valid and show neutral, readable Agent status words and pane main titles. Source confirms `.primary` at `Workbench.swift:137` and `NSColor.labelColor` at `Terminal.swift:192`; the active semibold title, accent frame and original status dot/shape remain. The light 260 capture's solid text-stroke samples are approximately **11.7:1** for “等待输入” against the selected-row ground and **13.8:1** for the pane main title against its ground, comfortably above the requested 4.5:1 floor. These are local rendered-pixel checks, not a full contrast audit. Dark text remains clearly legible in the recapture. No regression from this fix is visible in the supplied states.
- **F2 — resolved.** Current `DESIGN.md` describes the retained terminal workbench and explicit scope removals, neutral chrome, native label-color state/title text, four-section settings and content-sized search with a 44pt empty region / 320pt maximum. `.impeccable/design.json` matches those observations and parses as valid JSON. Obsolete file/launcher component claims are removed; acceptance limitations remain explicit. No new UI matrix review was performed.

## Remaining

Clear for **F1–F2 only**. This ship verdict covers the scored fixes, not the whole surface. Previously unrun IME, VoiceOver, keyboard full access/increased contrast, remote SSH, Tailcat, complete theme/accent/font matrix and C01–C90 native scenarios remain outside this verdict and must keep their recorded NOT RUN or partial status.

disposition: ship
