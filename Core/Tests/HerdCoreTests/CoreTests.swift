import XCTest
@testable import HerdCore

final class CoreTests: XCTestCase {
    func testFramingFragmentationAndLimits() throws {
        var buffer = LineBuffer(limit: 8)
        XCTAssertEqual(try buffer.append(Data("abc".utf8)), [])
        XCTAssertEqual(try buffer.append(Data("\ndef\n".utf8)), [Data("abc".utf8), Data("def".utf8)])
        XCTAssertThrowsError(try buffer.append(Data(repeating: 65, count: 9)))
    }
    func testDeviceScopedPaneIdentity() {
        XCTAssertNotEqual(PaneKey(device: "a", pane: "p1"), PaneKey(device: "b", pane: "p1"))
    }
    func testHerdrExtensionRecords() throws {
        let value: JSON = .object(["plugin_id": .string("example.tools"), "name": .string("Tools"), "version": .string("1.0"), "enabled": .bool(true), "panes": .array([.object(["id": .string("board"), "placement": .string("popup")])])])
        let plugin = try ExtensionInfo(value)
        XCTAssertEqual(plugin.id, "example.tools"); XCTAssertTrue(plugin.enabled)
        XCTAssertEqual(plugin.panes[0]["placement"].string, "popup")
        XCTAssertThrowsError(try ExtensionInfo(.object(["name": .string("Incomplete")])))
    }
    func testSearchPinyinAndLimit() {
        let search = Search([( "cn", "开发环境" )] + (0..<400).map { (String($0), "Agent \($0)") })
        XCTAssertEqual(search.query("kfhj"), ["cn"])
        XCTAssertEqual(search.query("agent").count, 50)
        measure { _ = search.query("agent 39") }
    }
    func testIncompleteSnapshotIsRejected() {
        XCTAssertThrowsError(try Session(.object(["workspaces": .array([])])))
    }
}
