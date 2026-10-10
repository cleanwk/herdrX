# Working on HerdrX

## Product boundary

HerdrX is a native macOS GUI for Herdr. Prefer presenting an existing Herdr capability over implementing a new domain feature in the client.

- Before adding an action, inspect the existing Herdr RPC, CLI and client call sites. Reuse the supported contract; report an upstream capability gap instead of inventing a parallel protocol.
- Herdr owns Space/Tab/Pane identity, names, lifecycle, layout and Agent detection/state. Server snapshots are authoritative. Client state supports presentation, selection, preferences and safe asynchronous operations.
- Keep terminal byte traffic outside observable UI state. Preserve mounted terminal surfaces during navigation and theme changes; detaching a client must preserve server sessions.
- Capture device and object identity before asynchronous work. Serialize conflicting writes where necessary, validate that the target still exists and retain usable UI state on failure.
- Read [PRODUCT.md](PRODUCT.md) when changing scope or behavior. Its current constraints govern which capabilities this GUI exposes.

## Implementation

- Follow the existing SwiftUI/AppKit split: SwiftUI composes the workbench and sheets; AppKit hosts terminal surfaces and native controls. Extend nearby implementations before introducing abstractions or dependencies.
- Keep reusable, UI-independent logic in `Core`; keep presentation and AppKit behavior in `App`. Herdr owns plugin execution through its existing manifests and APIs.
- For visual or interaction changes, read [DESIGN.md](DESIGN.md) and the relevant surface's validation record. Preserve the established native design and update its documented contract when it changes. Earlier screenshots establish history, not acceptance of new code.
- Keep English and Simplified Chinese strings in sync. Preserve native keyboard, focus, accessibility and cancellation paths.
- For Agent assets, use the provenance manifest in `Resources/Icon/AgentIcons.json` and `scripts/refresh-agent-icons.py`. Preserve upstream geometry/colors, original-versus-template rendering and fallbacks; retain licenses.
- Edit `project.yml` for Xcode configuration and regenerate with XcodeGen. Generated projects and `build/` are ignored outputs, not source files to commit.

## Verification

- Choose checks that exercise the changed behavior. Core logic uses `Core/Tests`; native rendering needs a built app. Build/test entry points are in [README.md](README.md), with the required CI sequence in `.github/workflows/ci.yml`.
- Exercise terminal mutations against an explicitly named disposable Herdr session and a separate client state directory. Use `HERDRX_STATE_DIR` for isolation. Label synthetic Agent metadata and stop only the test resources created for the task.
- Check asynchronous actions for stale targets, failure recovery and focus restoration. A successful compile does not establish successful interaction or visual acceptance.
- Report exactly which checks ran and which remain untested. Keep durable evidence in the relevant `docs/` validation record; keep temporary bundles, logs and fixture tooling under `build/` unless they are intentionally maintained test assets.

## PRs and releases

- Use a `codex/` branch for changes. PR descriptions state the resulting behavior, validation and material limits without conversation history.
- When a release is requested, inspect the latest published version and current workflows. Keep `VERSION`, `project.yml` and `docs/releases/<version>.md` consistent; update user-facing documentation for changed actions.
- Require successful checks for the current PR head before merging. Tag the merged commit and use `.github/workflows/release.yml` for universal packaging and signed update generation.
- Verify the published archive, `release.json`, checksums and signed appcast, then run/verify the existing Homebrew tap update workflow. Publication, local installation and Apple notarization are distinct outcomes; report only those actually completed.
- Keep signing material in the existing secret/keychain mechanisms. Commit source and public verification results, never credentials or private signing keys.
