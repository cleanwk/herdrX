import XCTest
@testable import HerdCore

final class NavigationPresentationTests: XCTestCase {
    func testNumericTabLabelDoesNotHideTaskButExplicitPaneNameSurvives() throws {
        let pane: JSON = .object(["pane_id": .string("p"), "agent": .string("codex"), "terminal_title_stripped": .string("Fix sidebar scrolling"), "cwd": .string("/repo")])
        let tab = try Item(.object(["tab_id": .string("t"), "label": .string("6")]), kind: "tab")
        XCTAssertEqual(DisplayTitle.agentRow(try Item(pane, kind: "pane"), tab: tab, fallback: "Task"), "Fix sidebar scrolling")
        var named = pane.object; named["label"] = .string("2026")
        XCTAssertEqual(DisplayTitle.agentRow(try Item(.object(named), kind: "pane"), tab: tab, fallback: "Task"), "2026")
        let authored = try Item(.object(["tab_id": .string("t"), "label": .string("Codex migration")]), kind: "tab")
        XCTAssertEqual(DisplayTitle.agentRow(try Item(pane, kind: "pane"), tab: authored, fallback: "Task"), "Codex migration")
    }
    func testNamedSessionIsGroupedOnlyAfterResolutionAndKeepsSelectedIdentity() {
        let manual = Device(id: "manual", displayName: "Server", endpoint: .init(kind: "ssh", target: "host", socketPath: "/run/herdr.sock"))
        let managed = Device(id: "managed", displayName: "Imported", endpoint: .init(kind: "ssh", target: "host", session: "default"), source: "herdr-machine:host")
        XCTAssertEqual(DeviceNavigationGroup.groups([manual, managed], resolvedSockets: [:]).count, 2)
        let groups = DeviceNavigationGroup.groups([manual, managed], resolvedSockets: ["managed": "/run/herdr.sock"])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].devices, [manual, managed])
        XCTAssertEqual(groups[0].representative(selected: "managed", connected: ["manual"]).id, "managed")
        XCTAssertEqual(groups[0].representative(selected: nil, connected: ["managed"]).id, "managed")
        XCTAssertTrue(groups[0].contains("manual"))
        XCTAssertEqual(DeviceNavigationGroup.groups([manual, managed], resolvedSockets: ["managed": "/run/other.sock"]).count, 2)
    }
    func testSimilarNamesDoNotMergeHostsPortsSSHConfigsOrSessions() {
        let endpoints: [Device.Endpoint] = [
            .init(kind: "ssh", target: "host", socketPath: "/run/h.sock"),
            .init(kind: "ssh", target: "another", socketPath: "/run/h.sock"),
            .init(kind: "ssh", target: "host", port: 2222, socketPath: "/run/h.sock"),
            .init(kind: "ssh", target: "host", socketPath: "/run/h.sock", sshConfig: "/tmp/config"),
            .init(kind: "ssh", target: "host", session: "work"),
            .init(kind: "ssh", target: "host", session: "default"),
            .init(kind: "local", socketPath: "/run/h.sock")
        ]
        let devices = endpoints.enumerated().map { Device(id: String($0.offset), displayName: "Same name", endpoint: $0.element) }
        XCTAssertEqual(DeviceNavigationGroup.groups(devices, resolvedSockets: [:]).count, devices.count)
    }
    func testActivityUsesAuthoritativeStatusAndUnreadAttention() {
        XCTAssertTrue(AgentActivityFilter.all.includes(status: "unknown", needsAttention: false))
        XCTAssertTrue(AgentActivityFilter.working.includes(status: "working", needsAttention: false))
        XCTAssertFalse(AgentActivityFilter.working.includes(status: "idle", needsAttention: true))
        XCTAssertTrue(AgentActivityFilter.attention.includes(status: "done", needsAttention: true))
        XCTAssertFalse(AgentActivityFilter.attention.includes(status: "done", needsAttention: false))
    }
}
