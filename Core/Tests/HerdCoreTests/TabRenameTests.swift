import XCTest
@testable import HerdCore

final class TabRenameTests: XCTestCase {
    func testNamesRejectBlankUnchangedAndMultilineButKeepUnicodeAndInteriorSpaces() {
        for value in ["", " \t\n", "原名", " 原名 ", "一\n二", "bad\0name"] {
            XCTAssertNil(TabName.changed(value, from: "原名"))
        }
        XCTAssertEqual(TabName.changed("  登录修复 · A / B #2 🚀  ", from: "原名"), "登录修复 · A / B #2 🚀")
        XCTAssertEqual(TabName.changed("A  B", from: "old"), "A  B")
        XCTAssertEqual(WorkbenchShortcut.action("r", modifiers: [.command, .option]), "renameTab")
        XCTAssertEqual(WorkbenchShortcut.action("w", modifiers: [.command, .shift]), "closePane")
    }

    @MainActor
    func testSuspendedFailureDoesNotOverlapOrPreventLaterRename() async throws {
        let queue = SerialOperationQueue()
        var release: CheckedContinuation<Void, Never>?
        var events: [String] = []
        var label = "original"
        let first = queue.enqueue {
            events.append("first starts")
            await withCheckedContinuation { release = $0 }
            events.append("first fails")
            throw Failure("offline")
        }
        let second = queue.enqueue {
            XCTAssertEqual(label, "original")
            events.append("second starts")
            label = "中文 · renamed"
        }
        while release == nil { await Task.yield() }
        XCTAssertEqual(events, ["first starts"])
        XCTAssertEqual(label, "original")
        release?.resume()
        do { try await first.value; XCTFail("Expected the first request to fail") } catch {}
        try await second.value
        XCTAssertEqual(events, ["first starts", "first fails", "second starts"])
        XCTAssertEqual(label, "中文 · renamed")
    }
}
