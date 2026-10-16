import XCTest
@testable import HerdCore

final class PaneActionTests: XCTestCase {
    func testScopedRenameUpdatesAgentRowAndUnchangedPaneKeepsEnrichment() throws {
        func snapshot(label: String, enriched: Bool) -> JSON {
            let pane: JSON = .object(["pane_id": .string("p"), "workspace_id": .string("w"), "tab_id": .string("t"), "terminal_id": .string("term"), "label": .string(label), "agent": .string("codex")])
            var fields: [String: JSON] = [
                "workspaces": .array([.object(["workspace_id": .string("w")])]),
                "tabs": .array([.object(["workspace_id": .string("w"), "tab_id": .string("t")])]),
                "panes": .array([pane]), "layouts": .array([])
            ]
            if enriched { var agent = pane.object; agent["title"] = .string("Enriched task"); fields["agents"] = .array([.object(agent)]) }
            return .object(fields)
        }
        let baseline = try Session(snapshot(label: "Before", enriched: true))
        let unchanged = try baseline.replacingWorkspace("w", with: Session(snapshot(label: "Before", enriched: false)))
        XCTAssertEqual(unchanged.agents, baseline.agents)
        let renamed = try baseline.replacingWorkspace("w", with: Session(snapshot(label: "After", enriched: false)))
        XCTAssertEqual(renamed.panes.first?.label, "After")
        XCTAssertEqual(renamed.agents.first?.label, "After")
    }

    func testCloseAndSplitPublishBeforeTwoSecondFullReadAndCannotBeRolledBack() async throws {
        let wire = PaneActionWire(), reader = SessionReader()
        let server = try TestRPCServer(requests: 100, concurrent: true, rawHandler: wire.respond)
        defer { withExtendedLifetime(server) {} }
        let rpc = RPC(path: server.path)
        var current = try Session(wire.snapshot), publication = SessionPublication()
        let other = current.panes.first { $0.id == "other-p" }
        for (index, method) in ["pane.close", "pane.split"].enumerated() {
            let fullStart = Date()
            let old = Task { try await reader.loadSnapshot(rpc) }
            let deadline = Date().addingTimeInterval(3)
            while wire.fullReads < index + 1, Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
            XCTAssertEqual(wire.fullReads, index + 1)
            let actionStart = Date()
            _ = try await rpc.call(method, ["pane_id": .string("right")])
            let fresh = try await reader.loadWorkspace("w", rpc)
            current = try XCTUnwrap(publication.apply(fresh, to: current, workspace: "w"))
            let elapsed = Date().timeIntervalSince(actionStart)
            XCTAssertLessThan(elapsed, 0.5, "Action still waits for full-session metadata")
            XCTAssertEqual(current.panes.first { $0.id == "other-p" }, other)
            XCTAssertEqual(current.panes.first { $0.id == "left" }?.terminal, "term-left")
            let members = current.panes.filter { $0.workspace == "w" }
            XCTAssertEqual(members.count, index == 0 ? 1 : 2)
            let layout = try XCTUnwrap(current.layouts.array.first { $0["tab_id"] == .string("t") })
            XCTAssertEqual(Set(layout["panes"].array.compactMap { $0["pane_id"].string }), Set(members.map(\.id)))
            if index == 0 {
                XCTAssertEqual(PaneLayoutGeometry.normalizedRect(layout["panes"].array[0]["rect"], in: layout["area"]), CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            let stale = try await old.value
            XCTAssertNil(try publication.apply(stale, to: current), "Old full read resurrected closed pane / removed new split")
            print("ACTION PERF \(method): visible=\(elapsed)s, outstanding full=\(Date().timeIntervalSince(fullStart))s")
        }
    }

    func testBadScopeKeepsCacheAndClosingLastPaneRemovesOnlyItsSpace() async throws {
        let wire = PaneActionWire(), reader = SessionReader()
        let server = try TestRPCServer(requests: 100, concurrent: true, rawHandler: wire.respond)
        defer { withExtendedLifetime(server) {} }
        let rpc = RPC(path: server.path), baseline = try Session(wire.snapshot)
        var current = baseline, publication = SessionPublication()
        wire.rejectWorkspace("permission_denied")
        do { _ = try await reader.loadWorkspace("w", rpc); XCTFail("Error text was mistaken for an authoritative deletion") }
        catch let error as RPC.RemoteError { XCTAssertEqual(error.code, "permission_denied") }
        wire.rejectWorkspace(nil)
        wire.breakLayout(true)
        do {
            let broken = try await reader.loadWorkspace("w", rpc)
            current = try XCTUnwrap(publication.apply(broken, to: current, workspace: "w"))
            XCTFail("Malformed layout was published")
        } catch { XCTAssertEqual(current, baseline) }
        wire.breakLayout(false)
        for id in ["left", "right"] { _ = try await rpc.call("pane.close", ["pane_id": .string(id)]) }
        let closed = try await reader.loadWorkspace("w", rpc)
        current = try XCTUnwrap(publication.apply(closed, to: current, workspace: "w"))
        XCTAssertEqual(current.spaces.map(\.id), ["other"])
        XCTAssertEqual(current.panes.map(\.id), ["other-p"])
        XCTAssertEqual(current.layouts.array.count, 1)
        let other = try await reader.loadWorkspace("other", rpc)
        XCTAssertThrowsError(try current.replacingWorkspace("w", with: other.session))
    }
}
