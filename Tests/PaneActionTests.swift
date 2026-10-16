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
        let server = try TestRPCServer(requests: 200, concurrent: true, fragmentSize: 65536, rawHandler: wire.respond)
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
        defer {
            desk.shutdown()
            canvas.entries = []
            for view in canvas.subviews where view is TerminalView { view.removeFromSuperview() }
            window.orderOut(nil); window.contentView = nil; window.close()
        }
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
        let closeStateTime = Date().timeIntervalSince(closeStart)
        render()
        let closeTime = Date().timeIntervalSince(closeStart)
        print("NATIVE CLOSE STAGES: state=\(closeStateTime)s layout=\(closeTime - closeStateTime)s total=\(closeTime)s")
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
        let splitStateTime = Date().timeIntervalSince(splitStart)
        render()
        let splitTime = Date().timeIntervalSince(splitStart)
        print("NATIVE SPLIT STAGES: state=\(splitStateTime)s layout=\(splitTime - splitStateTime)s total=\(splitTime)s")
        #expect(splitTime < 0.75, "Split waited for unrelated metadata")
        #expect(desk.terminals[left] === survivor)
        #expect(survivor.view.frame.width < oldWidth * 1.1)
        #expect(desk.focused?.pane == "new-3")
        try await background.value
        render()
        #expect(desk.terminals[right] == nil, "Late full snapshot resurrected closed native surface")
        #expect(desk.sessions[device.id]?.panes.contains(where: { $0.id == "new-3" }) == true)
        print("NATIVE ACTION PERF: close=\(closeTime)s split=\(splitTime)s with two-second full snapshots; survivor surface preserved")
        let evidence = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("build/tests/pane-actions.json")
        try FileManager.default.createDirectory(at: evidence.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: ["full_snapshot_delay_seconds": 2, "scoped_rpc_delay_seconds": 0.02,
            "native_close_seconds": closeTime, "native_split_seconds": splitTime,
            "close_state_seconds": closeStateTime, "split_state_seconds": splitStateTime,
            "configuration": "Release",
            "includes_native_layout": true], options: [.prettyPrinted, .sortedKeys]).write(to: evidence, options: .atomic)
    }

    private func wait(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(condition(), "Timed out waiting for native pane action")
    }
}
