# Theme correction validation

Recorded 2026-10-10 for the existing native macOS Operate surface. Source authority is `App/Theme.swift`, `App/ThemeColors.swift`, the native callers and pinned Ghostty definitions. [DESIGN.md](../../DESIGN.md), the [sidecar](../../.impeccable/design.json) and [surface brief](../../.impeccable/surfaces/app-workbench-swift.md) now describe this implementation. Reviewer acceptance remains in [VERDICT.md](VERDICT.md); the documenter does not assign its own ship verdict.

The [reported failure](evidence/user-reported.png) and [user reference](evidence/user-reference.png) remain immutable source images. This correction preserves the established geometry, native controls and purple slash identity. No web detector applies and no raster asset was created for shipping.

## Implemented color contract

- Navigation text uses explicit per-family semantic seeds. Foreground, secondary, accent and state roles are contrast-adjusted against canvas, chrome, hover and the strongest sidebar/tab selection surfaces. Raw selection hue remains separate from adjusted accent text/focus/tint. Secondary starts from a 0.20 foreground-to-background blend in both appearances, then receives the same check.
- Tokyo Night Day has a named HerdrX slate default/cursor/selection foreground and ANSI 0/8 adaptation. Gruvbox Light and Rosé Pine Dawn set ANSI 0 to their source default foreground. Existing Dracula/Vesper light companions retain their HerdrX provenance.
- Chromatic ANSI slots 1–6 and 9–14 receive hue-preserving shade adjustments toward 4.5:1 against the canvas. Palette slots also change when used as backgrounds. Slots 0/7/8/15 retain source values except the named adaptations.
- Ghostty minimum contrast is 1 and faint opacity is 0.85; cursor text is mapped when supplied. The earlier minimum-contrast-4.5 recommendation is superseded by the reviewer verdict because the pinned renderer substitutes pure black/white for failing colors. Application SGR, explicit indexed colors outside adapted ANSI slots and truecolor retain their meaning.

## Evidence

| Check | Recorded result and boundary |
| --- | --- |
| Family appearance coverage | The reviewer opened all 20 captures in `evidence/{catppuccin,tokyo-night,gruvbox,one,solarized,kanagawa,rose-pine,dracula,nord,vesper}-{light,dark}.png`, plus [Default light](evidence/default-light.png) and [Follow Herdr dark](evidence/follow-herdr-dark.png). |
| Corrected ANSI black | [Gruvbox light](evidence/gruvbox-light.png) and [Rosé Pine light](evidence/rose-pine-light.png) were recaptured using a unique test bundle and reopened by the reviewer. Dark ANSI 00 and pale diff-fill text are visible. These 1200×760pt windows supersede stale same-ID captures; other family captures use 980×620pt. This is a targeted color comparison, not a geometry regression pass. |
| Independent accents | Nine captures, `accent-blue-light.png` and `accent-{graphite,green,cyan,purple,amber,pink,red,orange}.png`, show changed selection/focus while ordinary text and terminal output remain stable. |
| Numerical app-role contrast | [contrast.txt](evidence/contrast.txt) reports 3,600 pairs across 12 choices × 2 appearances × 10 accent settings, minimum 4.500000001345258:1. The counted roles are foreground, secondary and accent against five authored surfaces. State roles use the same source algorithm but are not extra counted pairs in this record. This is token math, not measured glyph/pixel contrast. |
| Hidden-pane restoration | [hidden-pane-restored-dark.png](evidence/hidden-pane-restored-dark.png) records the mounted fixture restored after the theme change. |
| Reattach output continuity | [Before](evidence/before-reattach.png) and [after](evidence/after-reattach.png) captures accompany [before ANSI](evidence/fixture-before.ansi) and [after ANSI](evidence/fixture-after.ansi): exactly equal, 1,554 bytes with 39 distinct SGR sequences, including indexed and RGB runs. [Before metadata](evidence/pane-before.json) and [after metadata](evidence/pane-after.json) preserve terminal/pane IDs and process title. No PID field exists; independent PID continuity is not claimed. |
| System preference | [System AX](evidence/system-mode-ax.txt) shows the System radio option selected. The native effective-appearance callback exists. An actual macOS-driven transition was not exercised. |

The documenter read the source, validation records and verdict, and opened Tokyo Day, the corrected Gruvbox/Rosé Pine light captures and representative updater captures. It did not launch or operate the app, repeat the compiled contrast check or independently repeat reattachment. The reviewer inspected the full family/accent set. Fixtures use illustrative output and synthetic identity/state over real terminals and Herdr connections.

## Limits and handoff

Arbitrary foreground/background combinations, terminal truecolor and indexed colors outside the adapted ANSI slots are deliberately not rewritten. Their readability is not certified universally. No server color-replay defect was demonstrated or claimed fixed. This pass does not establish pixel identity with ACCM, production Agent activity, live Tailcat/SSH, notification delivery, VoiceOver, IME or older macOS behavior. Theme review does not accept updater or release publication work.

The authorized design-document refresh completes the documentation portion of F5 for reviewer re-scoring. The lead also updated `PRODUCT.md` coverage and `docs/Direction.md` icon/accent wording to match the current implementation. Existing icon provenance remains in [Resources/Icon/README.md](../../Resources/Icon/README.md). These changes are local and unpublished.
