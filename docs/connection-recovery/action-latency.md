# Post-mutation display latency — 0.1.21

The user's follow-up on 0.1.20 reported roughly two seconds between clicking Split
Right or closing a pane and seeing the new layout. A closing pane displayed the
terminal's expected `terminal … not found` exit until the UI caught up. The 0.1.20
changes reduced full-refresh latency, but every action still awaited that full
refresh. Its 2.526s synthetic result was not an acceptable interaction target.

`SessionReader.loadWorkspace` now has a separate short-read queue. It uses existing
`workspace.list`, workspace-scoped `tab.list`/`pane.list`, and `pane.layout` RPCs.
It validates scope/counts/layout membership and the target Space's before/after
topology. An absent Space from the authoritative list removes that Space after its
last pane closes. Other Spaces are not re-read and Agent enrichment is not on this
critical path. No pane identities or split geometry are predicted locally.

`Session.replacingWorkspace` updates the affected Space and retains the other
cached scopes, their ordering and enriched Agent records. `SessionPublication`,
used by Desk for both paths, rejects reads older than the last published result.
Read revisions are allocated when reads actually start, so a queued full read
that starts after an action can still publish current metadata. Short reads are
serialized with each other; independent Space patches cannot overtake one another.
Transport, connection, endpoint and focus checks remain in the UI path. Failed
scoped reads retain the cache and fall back to a full read without repeating the
mutation. The server still owns lifecycle and geometry.

Validation:

- `PaneActionTests` uses concurrent real Unix sockets with two-second full
  snapshots and 20ms individual scoped RPCs. It measures close/split completion,
  checks the scoped path stays below 500ms, preserves unrelated panes and survivor
  terminal identity, and feeds the late pre-mutation snapshot through the actual
  publication reducer to ensure it cannot undo the action. Invalid layout and
  closing the final pane are covered separately.
- `PaneActionInteractionTests` runs the real Desk action methods and native
  `TerminalCanvas` under the same delay, using a separate `HERDRX_STATE_DIR` and
  fixture socket. It checks removal of the closed native view, expansion of the
  survivor, native view identity, split focus, and late-result rejection. It
  requires visible action completion below 750ms and prints measured times.
  App launch services are disabled only for this hostless fixture; no default
  Herdr session, notification setup or machine discovery is started.
- The synthetic 9-Space/37-pane/23-Agent socket test now compares full and scoped
  timing and verifies untouched topology and Agent data. Existing real Herdr
  0.8.2/0.9.3 fixtures cover split/close geometry and survivor identity.
- Local Python release/update tests and Swift syntax checks pass. The complete
  macOS workflow for the current PR head remains required before merge/release.

These fixtures establish latency under controlled backend delays and actual
native reconciliation. User-device timing, live SSH/Tailcat RTT and a Space whose
own scoped response also exceeds Herdr's response limit remain separate limits.
