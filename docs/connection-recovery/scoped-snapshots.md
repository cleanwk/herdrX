# Large session recovery — 0.1.19

Herdr 0.9.3 can close a control socket after 8192 response bytes, before the NDJSON
newline. A large `session.snapshot` or `agent.list` then fails while independent
terminal attachments remain usable. This change adapts the HerdrX control reader;
it does not restart Herdr, change its dependency or repair its server-side EBADF.

`RPC.TruncatedResponse` identifies EOF before a complete response line. Only this
error enables scoped reads. Complete RPC errors (even with the same message),
invalid JSON, mismatched response IDs, timeouts and invalid snapshots do not.

Each configured device endpoint retains one serialized `SessionReader`. It starts
with `session.snapshot`; after truncation it uses `ping`, `workspace.list`, and
workspace-scoped `tab.list`/`pane.list`. One `pane.layout` per tab preserves the
server's rectangles and area origin. `pane.current` validates the focused pane;
empty sessions skip it because Herdr returns `pane_not_found`. `agent.list` remains
preferred until it truncates, then `agent.get(target: pane_id)` reads each detected
agent. Both fallback choices survive retries and SSH socket path changes. Changing
the configured endpoint or restarting the GUI creates a new reader.

Workspace IDs and tab/pane counts must match before and after the read. Scoped
counts, parent IDs, layout membership, focused pane and agent terminal identities
are checked before constructing a Session. Existing Session validation rejects
duplicate IDs and invalid topology. Desk publishes only a complete successful
Session after its existing connection/path/request identity guards. Failure keeps
the prior cache and mounted terminal surfaces.

The scoped API has no transaction/revision token across all responses. These
checks detect observed topology changes; they cannot promise that every field
was sampled at exactly the same instant or detect an ABA change between reads.
An individual scoped response that also truncates still fails without publishing.

Contracts were checked against [Herdr v0.9.3](https://github.com/herdrdev/herdr/tree/v0.9.3),
commit `7b116c05bfda646af39d2524c54e70c751f57ee8`, particularly
`src/app/api/session.rs`, `src/app/api/{workspaces,tabs,panes,agents}.rs`, and
`src/api/schema/{session,workspaces,tabs,panes,common}.rs`.

Validation is included in [PR #30 checks](https://github.com/cleanwk/herdrX/pull/30/checks):

- Real Unix socket regressions emit exactly 8192 bytes without LF, then test
  complete scoped reconstruction, agent fallback, layout preservation, sticky
  mode across transport changes and isolated readers for distinct endpoints.
- Concurrent refreshes share the first probe. Non-truncation errors, malformed
  lists, wrong scope, count changes, stale layout/current-pane/agent identities
  and failures at intermediate RPCs must not publish a partial Session. A later
  refresh recovers without repeating the known broken aggregate request.
- `scripts/herdr-integration-fixture.py` checks scoped request parameters and
  response fields against a real, isolated, explicitly named Herdr server with
  synthetic agent metadata. It stops only that fixture.
- The user's 9-workspace/37-pane/23-agent live session is not available here;
  physical-device acceptance remains untested.

## Action latency and completed snapshot publication — 0.1.20

The 0.1.19 reader serialized every scope and every caller. With a large session,
rename/split/create waited for both earlier background reads and their own full
read. Worse, Desk marked a new request as authoritative before it completed: a
later event refresh could discard the mutation's successful read. `create()` then
looked for the new pane in the old cache and skipped selecting it, making the plus
appear ineffective. Rename retained the old label until the later refresh, and
split could focus a pane before its layout was visible.

Each reader now numbers reads and Desk compares completed revisions, preserving
connection, socket and endpoint guards. Starting another request cannot suppress
a completed result; an older result cannot overwrite a newer published one.
Requests can share a pending read only before it starts, with identical socket
path and timeout. A request after a mutation therefore cannot join a read that
started before that mutation. Cancellation affects only that waiter. Queued work
continues after failure and the established sticky truncation fallback remains.

Workspace reads and per-pane Agent fallback use at most four concurrent sockets.
Each workspace retains its tab/pane/layout validation; results are assembled in
server order, independent of completion order. Final workspace topology checking
and complete-Session validation remain mandatory. No partial snapshot is published.

Regression coverage:

- Existing wire framing, topology/identity mismatch, intermediate failure,
  transport-change and empty-session cases use the same reader with a concurrency
  limit of one for deterministic fault placement.
- Production concurrency is tested over real Unix sockets with a synthetic
  9-Space / 37-pane / 23-Agent session and 20–40ms injected response latency.
  It compares serial/parallel timing, checks the four-socket ceiling and stable
  ordering, rejects a bad layout, preserves the previous cache and recovers.
- A gated socket test verifies a completed result remains available while a
  later read is blocked, twelve queued callers share one subsequent read, a
  cancelled waiter does not cancel its peers, and later requests get fresh data.

Local validation: 14 Python release/update tests and `git diff --check` passed.
This Linux executor cannot run AppKit or the Darwin Core tests; the current PR
head must pass the complete macOS workflow before merge/tag. User-device mouse
acceptance and live-session latency remain distinct from the synthetic benchmark.

The first [macOS run](https://github.com/cleanwk/herdrX/actions/runs/38873698614)
passed native tab dispatch, real Herdr integration, pane geometry and the Ghostty
suite, then exposed a SIGPIPE in the new delayed-socket stress fixture. The fixture
now explicitly retains its servers across async waits, and the accept loop owns
listener closure so a reused descriptor cannot be touched by an old loop.
The complete [PR #31 head checks](https://github.com/cleanwk/herdrX/pull/31/checks)
remain the release gate; this failed run is not a pass for the stress test.
