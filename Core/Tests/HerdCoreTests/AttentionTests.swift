import XCTest
@testable import HerdCore

final class AttentionTests: XCTestCase {
    func testSidebarRanksUnreadBeforeReadResultsAndUpdatesWhenRead() throws {
        var state = Attention()
        let old = try snapshot([("read", "done"), ("unread", "working"), ("working", "working"), ("blocked", "blocked")])
        let new = try snapshot([("read", "done"), ("unread", "done"), ("working", "working"), ("blocked", "blocked")])
        state.update(device: "a", old: old, new: new)
        func ordered() -> [String] {
            new.panes.enumerated().sorted {
                let left = state.sidebarRank(PaneKey(device: "a", pane: $0.element.id), status: $0.element.status)
                let right = state.sidebarRank(PaneKey(device: "a", pane: $1.element.id), status: $1.element.status)
                return (left, $0.offset) < (right, $1.offset)
            }.map(\.element.id)
        }
        XCTAssertEqual(ordered(), ["blocked", "working", "unread", "read"])
        XCTAssertEqual(state.sidebarRank(PaneKey(device: "b", pane: "unread"), status: "done"), 3)
        state.leave(PaneKey(device: "a", pane: "unread"))
        XCTAssertEqual(ordered(), ["blocked", "working", "read", "unread"])
    }
    func snapshot(_ statuses: [(String, String)]) throws -> Session {
        try Session(.object([
            "workspaces": .array([.object(["workspace_id": .string("w1")])]),
            "tabs": .array([.object(["workspace_id": .string("w1"), "tab_id": .string("t1")])]),
            "panes": .array(statuses.map { .object(["pane_id": .string($0.0), "workspace_id": .string("w1"), "tab_id": .string("t1"), "agent": .string("codex"), "agent_status": .string($0.1)]) })
        ]))
    }
    func testUnreadTransitionsAndDeviceIsolation() throws {
        var state = Attention()
        let done = try snapshot([("p1", "done")]), working = try snapshot([("p1", "working")])
        state.update(device: "a", old: nil, new: done)
        XCTAssertTrue(state.unread.isEmpty)
        state.update(device: "a", old: working, new: done)
        state.update(device: "b", old: working, new: done)
        XCTAssertEqual(state.unread.count, 2)
        state.leave(PaneKey(device: "a", pane: "p1"))
        XCTAssertEqual(state.unread, [PaneKey(device: "b", pane: "p1")])
        state.update(device: "b", old: done, new: working)
        XCTAssertTrue(state.unread.isEmpty)
        state.update(device: "b", old: working, new: done)
        state.update(device: "b", old: done, new: try snapshot([]))
        XCTAssertTrue(state.unread.isEmpty)
    }
    func testOrderingDiffersFromAggregation() throws {
        let values = ["unknown", "idle", "done", "working", "blocked"]
        XCTAssertEqual(values.sorted { Attention.rank($0) < Attention.rank($1) }, values.reversed())
        var state = Attention()
        let old = try snapshot([("p1", "working"), ("p2", "working")])
        let new = try snapshot([("p1", "done"), ("p2", "working")])
        state.update(device: "a", old: old, new: new)
        XCTAssertEqual(state.summary(device: "a", panes: new.panes), "unread")
        state.leave(PaneKey(device: "a", pane: "p1"))
        XCTAssertEqual(state.summary(device: "a", panes: new.panes), "working")
        XCTAssertFalse(state.needsAttention(PaneKey(device: "a", pane: "p1"), status: "done"))
        let blocked = try snapshot([("p1", "done"), ("p2", "working"), ("p3", "blocked")])
        state.update(device: "a", old: old, new: blocked)
        XCTAssertEqual(state.summary(device: "a", panes: blocked.panes), "blocked")
        XCTAssertTrue(state.needsAttention(PaneKey(device: "a", pane: "p3"), status: "blocked"))
        XCTAssertFalse(state.needsAttention(PaneKey(device: "a", pane: "p2"), status: "working"))
        let quiet = try snapshot([("p1", "idle"), ("p2", "unknown")])
        state.update(device: "a", old: blocked, new: quiet)
        XCTAssertNil(state.summary(device: "a", panes: quiet.panes))
    }
}
