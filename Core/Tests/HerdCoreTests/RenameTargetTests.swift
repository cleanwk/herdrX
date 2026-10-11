import XCTest
@testable import HerdCore

final class RenameTargetTests: XCTestCase {
    private func session(paneTab: String = "t1") throws -> Session {
        try Session(.object([
            "workspaces": .array([.object(["workspace_id": .string("w1")]), .object(["workspace_id": .string("w2")])]),
            "tabs": .array([.object(["tab_id": .string("t1"), "workspace_id": .string("w1")]), .object(["tab_id": .string("t2"), "workspace_id": .string("w2")])]),
            "panes": .array([.object(["pane_id": .string("p1"), "tab_id": .string(paneTab), "workspace_id": .string(paneTab == "t1" ? "w1" : "w2")])])
        ]))
    }
    func testCapturedParentScopeRejectsMovedAndMissingTargets() throws {
        let snapshot = try session()
        let pane = RenameTarget.pane(id: "p1", tab: "t1", space: "w1")
        XCTAssertTrue(pane.exists(in: snapshot))
        XCTAssertFalse(pane.exists(in: try session(paneTab: "t2")))
        XCTAssertFalse(pane.exists(in: nil))
        XCTAssertFalse(RenameTarget.pane(id: "deleted", tab: "t1", space: "w1").exists(in: snapshot))
        XCTAssertTrue(RenameTarget.tab(id: "t1", space: "w1").exists(in: snapshot))
        XCTAssertFalse(RenameTarget.tab(id: "t1", space: "w2").exists(in: snapshot))
        XCTAssertTrue(RenameTarget.space(id: "w2").exists(in: snapshot))
        XCTAssertFalse(RenameTarget.space(id: "deleted").exists(in: snapshot))
    }
    func testTargetsUseOnlyExistingRenameContracts() {
        let targets: [(RenameTarget, String, String)] = [(.space(id: "w1"), "workspace.rename", "workspace_id"), (.tab(id: "t1", space: "w1"), "tab.rename", "tab_id"), (.pane(id: "p1", tab: "t1", space: "w1"), "pane.rename", "pane_id")]
        for (target, method, parameter) in targets {
            XCTAssertEqual(target.method, method)
            XCTAssertEqual(target.parameters(name: "中文 · A  B"), [parameter: .string(target.id), "label": .string("中文 · A  B")])
        }
    }
}
