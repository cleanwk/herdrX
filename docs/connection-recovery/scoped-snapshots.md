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
