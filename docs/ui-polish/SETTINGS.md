# Settings and navigation review

Independent review A, 2026-10-10. Reviewed `App/Preferences.swift`, `DeviceSwitcher.swift`, `Sidebar.swift`, `SearchInput.swift` and `PreferenceMenu.swift` against PRODUCT.md, DESIGN.md and the Impeccable polish/craft-floor guidance. The main reviewer ran the context loader and owns the final build and running-app inspection. This reviewer did not operate the user's app or read other reviewers' conclusions.

## Evidence and findings

The incumbent evidence is `docs/accm-fidelity/screenshots/settings-appearance.png`, `settings-terminal.png`, `settings-connections.png`, `settings-notifications.png`, `device-switcher.png`, and `docs/app-updates/evidence/settings.png`. These are existing Chinese-language captures, not screenshots of this change. Current source retains their relevant control types and dimensions; the updater capture's fixture version is historical.

| Finding | Evidence | Change |
| --- | --- | --- |
| Accent choices can exceed the Appearance content column with English text. | Source gives controls 312pt, while nine 22pt swatches and nine 6pt gaps already occupy 252pt before “Follow theme.” Existing captures cover Chinese only. | Use `ViewThatFits` to keep the existing single row when it fits and move Follow Theme under the swatches when needed. Preserve all nine choices and their order. |
| Follow Theme has an accessibility selection trait but no visible selected state. | Source and Appearance capture. | Add a reserved checkmark beside Follow Theme; switching selection does not move its label. |
| Segmented controls assume the width of Chinese labels. | Appearance and Terminal constrain their controls to 150pt, including English “System mode” and “Light weight.” | Keep a 150pt minimum and allow the native controls' intrinsic width. |
| Growing Terminal content has no vertical recovery path. | Terminal has a fixed 410pt page, a variable-size preview up to 22pt, optional import errors and no scroll view. | Make Terminal scrollable. Appearance is also scrollable when its accent fallback adds a line. Default content padding and overall settings window dimensions remain intact. |
| Notifications shifts horizontally with the intrinsic width of its copy. | The Chinese capture starts its content near 73pt despite a 24pt declared inset; the inner stack has no width expansion. | Expand the stack to the available width with leading alignment before applying the existing 24pt inset. |
| About helper copy uses an unrelated checkbox indentation. | The updater capture uses trailing switches, but descriptions start 20pt to the right of their labels. | Align descriptions with the switch labels and allow vertical wrapping. |
| Open-source notices are loaded during every About body evaluation. | The file read is inside the DisclosureGroup view expression. | Cache immutable bundled notice text once; keep localized fallback lookup at display time. |
| Long device names can compete with the connection actions. | Saved-device row has an unconstrained title beside Edit, Retry and Remove. | Truncate the name to one line in the middle and retain the full name in help. |
| Native popup identity depends on translated display text. | `selectItem(withTitle:)` and the action's first matching title cannot distinguish two choices with the same title; identity-only changes are not detected. | Store setting IDs in each NSMenuItem's representedObject. Compare IDs and titles when updating and select/write by ID. Preserve separator structure and reuse unchanged menus. |

No independent defect requiring edits was found in DeviceSwitcher, Sidebar or SearchInput in this bounded pass. Their rendered behaviors outside the supplied captures remain subject to the main review.

## Validation completed

- `swiftc -frontend -parse App/Preferences.swift App/PreferenceMenu.swift` passed.
- `git diff --check` passed.
- `swiftc -module-cache-path /tmp/herdrx-settings-module-cache -typecheck App/PreferenceMenu.swift App/Localization.swift` passed. A first attempt using the compiler's default cache directory was blocked by filesystem restrictions; relocating only the temporary cache resolved it.
- A temporary native AppKit/SwiftUI harness mounted the real PreferenceMenu in an offscreen NSHostingView without opening a window. It verified that duplicate display titles remain two choices; the selected ID is correct; selection writes the chosen ID; changed/reordered IDs are handled despite unchanged display titles; the palette separator remains at index 2; and unchanged choices retain the same NSMenuItem instance. All checks passed.

The harness is temporary validation, not a new repository test suite. No device connection, update installation, preference migration or terminal session mutation was performed by this reviewer.

## Final verification owned by the main review

The full application must build with these changes, and the single confirmation capture round should include:

- Appearance in English and Chinese: all accents, visible Follow Theme selection, full segmented labels, aligned menus and access to Language.
- Terminal in English at 13.5pt and 22pt: full control labels, preview and reachable content. Import-error text should also remain reachable.
- Notifications in both languages: stable 24pt leading inset and usable disabled sound state.
- About in English and Chinese: descriptions align with switch labels; longer status/failure text remains scrollable.
- Connections with a long device name: actions remain usable and full identity is available in help.

The English overflow findings above are source-constraint findings until these final renders are inspected. This review does not claim live VoiceOver, IME, SSH/Tailcat, notification delivery, updater network/install or older-macOS validation.
