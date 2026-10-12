import AppKit
import HerdCore
import Testing

@Suite(.serialized) @MainActor struct FloatingTerminalTests {
    @Test func commandExitClosesFloatingWindowWithoutInvokingUserClose() async throws {
        _ = NSApplication.shared
        let popup = FloatingTerminal(title: "Herdr popup fixture", command: "printf 'ACC popup fixture'; sleep 0.3")
        var closed = 0, userClosed = 0
        popup.didClose = { closed += 1 }; popup.userClosed = { userClosed += 1 }
        popup.showWindow(nil); popup.window?.makeKeyAndOrderFront(nil)
        defer { popup.finish() }
        let deadline = Date().addingTimeInterval(5)
        while closed == 0, Date() < deadline { try await Task.sleep(for: .milliseconds(30)) }
        #expect(closed == 1)
        #expect(userClosed == 0)
        #expect(popup.window?.isVisible == false)
    }
    @Test func closingWindowStopsOnlyItsOwnedPTY() async throws {
        _ = NSApplication.shared
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("herdrx-popup-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: marker) }
        let popup = FloatingTerminal(title: "Close fixture", command: "echo $$ > " + quote(marker.path) + "; exec /bin/sleep 30")
        var closed = 0, userClosed = 0
        popup.didClose = { closed += 1 }; popup.userClosed = { userClosed += 1 }
        popup.showWindow(nil)
        defer { popup.finish() }
        let start = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: marker.path), Date() < start { try await Task.sleep(for: .milliseconds(30)) }
        let text = try String(contentsOf: marker, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = try #require(Int32(text))
        popup.window?.makeKeyAndOrderFront(nil)
        popup.window?.makeFirstResponder(popup.terminalView)
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: popup.window!.windowNumber, context: nil, characters: "w", charactersIgnoringModifiers: "w", isARepeat: false, keyCode: 13))
        #expect(popup.terminalView.performKeyEquivalent(with: event))
        let deadline = Date().addingTimeInterval(4)
        while kill(pid, 0) == 0, Date() < deadline { try await Task.sleep(for: .milliseconds(30)) }
        #expect(kill(pid, 0) != 0)
        #expect(closed == 1); #expect(userClosed == 1)
    }
}
