import AppKit
import HerdCore
import Testing

@Suite(.serialized) @MainActor struct PaneActionInteractionTests {
    @Test func deskClosesAndSplitsBeforeFullRefreshAndKeepsNativeSurvivorMounted() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("hx-pane-action-" + UUID().uuidString)
        let previousState = ProcessInfo.processInfo.environment["HERDRX_STATE_DIR"]
        setenv("HERDRX_STATE_DIR", root.path, 1)
        defer {
            if let previousState { setenv("HERDRX_STATE_DIR", previousState, 1) } else { unsetenv("HERDRX_STATE_DIR") }
            try? FileManager.default.removeItem(at: root)
        }
        let wire = PaneActionWire()
        let server = try TestRPCServer(requests: 200, concurrent: true, rawHandler: wire.respond)
        let desk = Desk(startServices: false)
        defer { desk.shutdown(); wire.stopEvents.signal(); withExtendedLifetime(server) {} }
        let device = Device(id: "fixture", displayName: "Isolated latency fixture", endpoint: .init(kind: "local", socketPath: server.path))
        desk.add(device)
        try await wait { desk.canWrite(device.id) && desk.sessions[device.id] != nil }
        desk.select(device: device.id, space: "w", tab: "t")
        desk.canvasSize = CGSize(width: 900, height: 600)
        let left = PaneKey(device: device.id, pane: "left"), right = PaneKey(device: device.id, pane: "right")
        let survivor = try #require(desk.terminals[left]), removed = try #require(desk.terminals[right])
        let canvas = TerminalCanvas.Canvas(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let window = NSWindow(contentRect: canvas.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = canvas; window.orderFront(nil)
        defer { window.close() }
        func render() {
            canvas.entries = desk.canvas; canvas.focused = desk.focused; canvas.focusRevision = desk.focusRevision; canvas.titles = desk.paneTitles
            canvas.needsLayout = true; canvas.layoutSubtreeIfNeeded()
        }
        render()
        let oldWidth = survivor.view.frame.width
        let previousReads = wire.fullReads
        let background = Task { try await desk.refresh(device.id, client: RPC(path: server.path)) }
        try await wait { wire.fullReads > previousReads }

        let closeStart = Date()
        desk.objectAction(device: device.id, method: "pane.close", params: ["pane_id": .string("right")])
        try await wait { desk.sessions[device.id]?.panes.contains(where: { $0.id == "right" }) == false }
        render()
        let closeTime = Date().timeIntervalSince(closeStart)
        #expect(closeTime < 0.75, "Close waited for the two-second background read")
        #expect(desk.terminals[right] == nil)
        #expect(removed.view.superview == nil, "Closed native surface remained mounted")
        #expect(desk.terminals[left] === survivor)
        #expect(survivor.view.superview === canvas)
        #expect(survivor.view.frame.width > oldWidth * 1.8, "Survivor did not expand")
        #expect(desk.layoutRects.first { $0.0 == left }?.1 == CGRect(x: 0, y: 0, width: 1, height: 1))

        let splitStart = Date()
        desk.split(horizontal: true, target: left)
        try await wait { desk.sessions[device.id]?.panes.contains(where: { $0.id == "new-3" }) == true }
        render()
        let splitTime = Date().timeIntervalSince(splitStart)
        #expect(splitTime < 0.75, "Split waited for unrelated metadata")
        #expect(desk.terminals[left] === survivor)
        #expect(survivor.view.frame.width < oldWidth * 1.1)
        #expect(desk.focused?.pane == "new-3")
        try await background.value
        render()
        #expect(desk.terminals[right] == nil, "Late full snapshot resurrected closed native surface")
        #expect(desk.sessions[device.id]?.panes.contains(where: { $0.id == "new-3" }) == true)
        print("NATIVE ACTION PERF: close=\(closeTime)s split=\(splitTime)s with two-second full snapshots; survivor surface preserved")
    }

    private func wait(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(condition(), "Timed out waiting for native pane action")
    }
}
