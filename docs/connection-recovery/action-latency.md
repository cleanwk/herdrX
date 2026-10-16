# Post-mutation display latency — 0.1.21

The user's follow-up on 0.1.20 reported roughly two seconds between clicking Split
Right or closing a pane and seeing the new layout. A closing pane displayed the
terminal's expected `terminal … not found` exit until the UI caught up. The 0.1.20
changes reduced full-refresh latency, but every action still awaited that full
refresh. Its 2.526s synthetic result was not an acceptable interaction target.

`SessionReader.loadWorkspace` now has a separate short-read queue. It uses existing
`workspace.get`, workspace-scoped `tab.list`/`pane.list`, and `pane.layout` RPCs.
It validates scope/counts/layout membership and the target Space's before/after
topology. Only the server's `workspace_not_found` error removes that Space after
its last pane closes; other errors retain the cache. Independent workspace/tab/pane reads
run concurrently, as do up to four tab layouts. Other Spaces are not re-read and Agent enrichment is not on this
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
  It runs in its own test process, separate from the selection/scroll suite, and
  detaches its native surfaces during teardown. Both test invocations have bounded
  execution time. Timing fixtures send each normal response in a single write,
  matching Herdr; the existing transport and large-session tests retain deliberate
  17-byte fragmentation coverage. Native tests use the shipping Release optimization
  level and report state-publication and native-layout times separately.
- The synthetic 9-Space/37-pane/23-Agent socket test now compares full and scoped
  timing and verifies untouched topology and Agent data. Existing real Herdr
  0.8.2/0.9.3 fixtures cover split/close geometry and survivor identity.
- Local Python release/update tests and Swift syntax checks pass. The complete
  macOS workflow for the current PR head remains required before merge/release.
- The initial macOS run passed the native interaction test but failed strict
  Core latency thresholds (0.495s close, 0.632s split, 0.804s large-session scope).
  It is not a successful release gate. The follow-up replaces global workspace
  lists with individual workspace reads and parallelizes independent lists and
  layouts without increasing the four-socket ceiling of full background reads.
- A later run passed native action checks (0.701s close / 0.733s split including
  layout, with 17-byte fragmented fixture writes), then hung in the existing
  `stationaryEdgesGrowAndCancellationStops` selection test. That run was cancelled
  for diagnosis, not counted as a pass. Process isolation and explicit view
  teardown keep the Desk fixture out of the independent selection test process.
- The isolated Debug run then completed but missed the native timing target
  (0.909s close / 1.032s split); structural assertions passed. It is not counted as
  a pass. Performance is gated on the shipping Release configuration, retaining
  the same 750ms threshold and all structural assertions, with stage timing in
  the evidence to distinguish read/publication from native layout work.
- Per-RPC tracing then found the isolated server taking 58–169ms for nominal
  20ms delays in the background xctest process. Client publication followed the
  final response by about 1ms; native layout took 8–21ms. The socket fixture now
  holds a foreground latency-critical process activity and assigns user-initiated
  QoS to its worker threads. Further traces showed that `Thread.sleep` still
  coalesced nominal 20ms sleeps to 150–168ms despite that activity. Both latency
  fixtures now inject delays with strict dispatch timers and zero leeway.
  Traces report actual wait time as well as handler time.
  This only changes the fixture; production scheduling and all timing targets
  remain unchanged.

These fixtures establish latency under controlled backend delays and actual
native reconciliation. User-device timing, live SSH/Tailcat RTT and a Space whose
own scoped response also exceeds Herdr's response limit remain separate limits.
