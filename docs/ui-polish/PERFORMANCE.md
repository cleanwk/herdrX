# Native UI performance review

Recorded 2026-10-10 on arm64 macOS 27.0.1 (26A434), Apple Swift 6.4. Baseline: `6ffc7bcefaa5b2cdbc9ba59c5dea2695f721652d`.

Scope: `App/Desk.swift`, `Navigation.swift`, `Objects.swift`, `Theme.swift` and `ThemeColors.swift`. The measured fixes are confined to `Desk.swift` and `Theme.swift`; this review did not change visual tokens, terminal traffic, mounted sessions or terminal configuration. The work follows the native macOS Operate context in `PRODUCT.md` and `DESIGN.md`. No web detector applies.

## Findings and fixes

**P2 — Repeated color derivation during drawing.** Every resolution of `Theme.content`, `foreground`, `secondary`, `chrome`, `selection` or `accent` rebuilt the complete `ThemeColors`. That repeatedly ran the same 24-step contrast searches against five surfaces for the same palette, appearance and accent. AppKit/SwiftUI callers resolve these semantic colors throughout sidebars, tabs and pane chrome.

`Theme.roles` now keeps at most two entries, one per appearance for the current effective family and accent. Every read checks the preference key, including the resolved Follow Herdr family. A lock protects the cache because dynamic `NSColor` resolution is not isolated to an actor. Preference changes discard the old pair; color calculations and palette definitions are unchanged.

**P2 — Search index sorting rescanned all panes for each comparison.** `Desk.reindex` looked up each side's status with `panes.first` inside the sort comparator, and rebuilt the Agent list by filtering all panes for each tab. Opening Search, session changes and branch refreshes call this path on the main actor. Identical derived content also reassigned all three published Agent/search properties.

The method now groups tabs and panes once, looks up precomputed status ranks by full search row ID, and assigns derived state only when its contents or search ordering change. Existing device/space/tab order, status priority, recency, labels and ID tie-breaks remain intact. Search documents are still updated when ordering changes even if the row lookup contents remain the same.

## Measurement

Run from the repository after Swift package resolution:

```sh
python3 scripts/benchmark-ui.py --baseline 6ffc7bcefaa5b2cdbc9ba59c5dea2695f721652d
```

The script compiles production method bodies with `swiftc -O`, actual `ThemeColors`, pinned Ghostty theme definitions and HerdCore models. It extracts theme code before terminal controller setup and places the actual index methods in a harness without constructing `Desk`, connecting devices, creating terminals or opening windows. Preferences use a volatile domain; user settings are not written. The index harness counts assignments in place of published-property setters and replaces localized `L` calls with the supplied English key.

Before changing either measured path, the corresponding unmodified control was run beside the baseline: color results were 1.00x/0.99x; reindex results were 0.99x/1.00x. Thus the harness did not introduce the observed improvement.

| Workload | Baseline median | Fixed median | Ratio |
| --- | ---: | ---: | ---: |
| 120 dynamic role resolutions, light | 24.290 ms | 0.182 ms | 133.37x |
| 120 dynamic role resolutions, dark | 24.276 ms | 0.177 ms | 136.90x |
| Warm reindex, 100 panes | 16.239 ms | 1.005 ms | 16.16x |
| Warm reindex, 1,000 panes | 1,542.548 ms | 12.033 ms | 128.19x |

Color timing uses seven samples of twenty batches, each batch resolving six dynamic roles twenty times. The reported color results are from the isolated color-only run. The later combined run overlapped a separately initiated app build and measured baseline colors at 43.181/26.792 ms, fixed at 0.185/0.179 ms; those noisier ratios are deliberately not substituted above.

Index timing uses three samples of two warm reindexes after initial document normalization. At both sizes, the six unchanged reindexes produced **18 → 0 assignments** to the three derived properties. An earlier unmodified index control used seven samples of five iterations and measured 16.466 ms at 100 panes and 1,553.955 ms at 1,000 panes. The final index measurements may overlap the app build; treat exact timing and ratios as local diagnostic evidence, not a cross-machine performance guarantee.

The final confirmation, after adding separate invalidation/device cases, exited 0: 486 role comparisons passed; index content/order checks passed; unchanged assignments remained 18 → 0. Its index medians were 16.335 → 1.018 ms and 1,547.174 → 11.993 ms. `git diff --check` also passed.

## Correctness and limits

- 486 exact sRGB component comparisons cover all twelve palette choices, theme-derived plus nine explicit accents, alternating light/dark warm reads and changes to the Follow Herdr resolved family. Cache results equal the baseline, including authored surfaces.
- Index fixtures compare Agent order, every search row's ID/label/detail and six search query result lists. Separate status, recency, branch, cross-device duplicate IDs and removal changes check invalidation and device boundaries. Reindexing unchanged data must produce zero derived assignments.
- No additional changes were justified by measurement in `Navigation.swift`, `Objects.swift` or `ThemeColors.swift` during this review. Some bounded array searches remain; these were not reported as user-visible defects without evidence.
- These are component benchmarks with synthetic 100/1,000-pane fixtures, not measured application frame times, startup, scrolling, terminal throughput or memory profiles. Fewer assignments do not establish an equal reduction in SwiftUI body evaluations because SwiftUI may coalesce notifications.
- First-use color derivation remains a cache miss. Status-color contrast calculations and terminal ANSI adaptation remain unchanged. The index retains one current ordered row array; the theme retains at most two role sets.
- No GUI was operated by this review. Full app build/tests and any live visual verification are performed by the coordinating review; their outcome belongs in its validation record.
