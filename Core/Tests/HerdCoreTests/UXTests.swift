import XCTest
@testable import HerdCore

final class UXTests: XCTestCase {
    func testClosingSelectionUsesSurvivingNeighbourWithoutChangingBackgroundSelection() {
        XCTAssertEqual(NeighbourSelection.resolve("b", previous: ["a", "b", "c", "d"], current: ["a", "c", "d"]), "c")
        XCTAssertEqual(NeighbourSelection.resolve("d", previous: ["a", "b", "c", "d"], current: ["a", "b"]), "b")
        XCTAssertEqual(NeighbourSelection.resolve("a", previous: ["a", "b"], current: ["new", "a"]), "a")
        XCTAssertNil(NeighbourSelection.resolve("a", previous: ["a"], current: []))
    }
    func item(_ fields: [String: JSON], kind: String = "pane") throws -> Item { try Item(.object([kind + "_id": .string("id")].merging(fields) { _, b in b }), kind: kind) }
    func testShortcutsMatchCompleteModifiersAndExcludeRemovedCommands() {
        XCTAssertNil(WorkbenchShortcut.action("n", modifiers: .command))
        XCTAssertNil(WorkbenchShortcut.action("e", modifiers: [.command, .shift]))
        XCTAssertNil(WorkbenchShortcut.action("f", modifiers: [.command, .shift]))
        XCTAssertNil(WorkbenchShortcut.action("t", modifiers: [.command, .control]))
        XCTAssertNil(WorkbenchShortcut.action("v", modifiers: .command))
        XCTAssertEqual(WorkbenchShortcut.action("w", modifiers: .command), "close")
        XCTAssertEqual(WorkbenchShortcut.action("w", modifiers: [.command, .option]), "closeTab")
        XCTAssertEqual(WorkbenchShortcut.action("d", modifiers: [.command, .shift]), "splitDown")
    }
    func testTitlesUseExplicitIdentityBeforeToolCommands() throws {
        let pane = try item(["label": .string(" 修复\n 登录  "), "title": .string("codex resume --last"), "agent": .string("codex")])
        let tab = try item(["label": .string("用户任务")], kind: "tab")
        XCTAssertEqual(DisplayTitle.pane(pane, tab: tab), "修复 登录")
        let unnamed = try item(["title": .string("codex resume --last"), "agent": .string("codex"), "terminal_title_stripped": .string("codex")])
        XCTAssertEqual(DisplayTitle.pane(unnamed, tab: tab), "用户任务")
        XCTAssertEqual(DisplayTitle.pane(unnamed, tab: nil), "codex")
        let titled = try item(["title": .string("修复搜索"), "agent": .string("codex")])
        XCTAssertEqual(DisplayTitle.pane(titled, tab: tab), "修复搜索")
        XCTAssertEqual(DisplayTitle.detail(["Device", " ", nil, "Space"]), "Device · Space")
    }
    func testSelectionSurvivesReorderAndCannotEnterDeletedObject() {
        var selection = SearchSelection(); selection.reset(["a", "b", "c"]); selection.move(1, in: ["a", "b", "c"])
        selection.reconcile(["c", "a", "b"]); XCTAssertEqual(selection.id, "b")
        selection.reconcile(["c", "a"]); XCTAssertNil(selection.id)
        selection.move(1, in: ["c", "a"]); XCTAssertEqual(selection.id, "c")
    }
    func testShellTitlesShortenOnlyRecognizableLocations() throws {
        let fields: [String: JSON] = ["cwd": .string("/Users/dev/code/My App"), "terminal_title_stripped": .string("dev@host:~/code/My App")]
        XCTAssertEqual(DisplayTitle.terminal(try item(fields)), "My App")
        XCTAssertEqual(DisplayTitle.terminal(try item(fields.merging(["label": .string("Release #2")]) { _, b in b })), "Release #2")
        for title in ["npm test (3/10)", "dev@host:~/another", "My authored title"] {
            XCTAssertEqual(DisplayTitle.terminal(try item(fields.merging(["terminal_title_stripped": .string(title)]) { _, b in b })), title)
        }
        XCTAssertEqual(DisplayTitle.terminal(try item(["cwd": .string("/repo/herdrX"), "terminal_title_stripped": .string("/repo/herdrX")])), "herdrX")
        XCTAssertEqual(DisplayTitle.terminal(try item(["cwd": .string("/Users/dev/项目/发布 检查"), "terminal_title_stripped": .string("dev@host:~/项目/发布 检查")])), "发布 检查")
        XCTAssertEqual(DisplayTitle.terminal(try item(["cwd": .string("/")])), "/")
        XCTAssertEqual(DisplayTitle.terminal(try item([:]), fallback: "终端"), "终端")
    }
    func testConnectionDraftResetDoesNotCarrySSHOptions() throws {
        var draft = ConnectionDraft(Device(id: "ssh", displayName: "Build", endpoint: .init(kind: "ssh", target: "fixture", port: 2222, socketPath: "/tmp/session.sock", sshConfig: "/tmp/config")))
        XCTAssertEqual(try draft.device().id, "ssh")
        draft = ConnectionDraft(); XCTAssertNil(draft.id); XCTAssertEqual(draft.port, ""); XCTAssertEqual(draft.sshConfig, ""); XCTAssertFalse(draft.local)
        draft.name = "Local"; draft.socket = "/tmp/local.sock"; draft.local = true; draft.port = "bad"; draft.target = "-bad"
        let local = try draft.device(); XCTAssertNil(local.endpoint.port); XCTAssertNil(local.endpoint.target)
        draft.socket = "/tmp/bad\n"; XCTAssertThrowsError(try draft.device())
    }
    func testSearchUpdateRetainsIdentityAndPinyinAcrossStatusReorders() {
        var search = Search(documents: [.init(id: "a", name: "登录修复", context: "device a"), .init(id: "b", name: "文档", context: "device b")])
        XCTAssertEqual(search.query("dlxf"), ["a"])
        search.update(documents: [.init(id: "b", name: "文档", context: "device b"), .init(id: "a", name: "登录修复", context: "device a")])
        XCTAssertEqual(search.query("dlxf"), ["a"])
        search.update(documents: [.init(id: "a", name: "新的名称", context: "device a")]); XCTAssertTrue(search.query("dlxf").isEmpty)
    }
}
