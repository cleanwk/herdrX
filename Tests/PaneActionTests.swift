import AppKit
import Combine
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
        var closePublication: Date?, splitPublication: Date?
        let publications = desk.$sessions.sink { sessions in
            if let panes = sessions[device.id]?.panes {
                if !panes.contains(where: { $0.id == "right" }), closePublication == nil { closePublication = Date() }
                if panes.contains(where: { $0.id == "new-3" }), splitPublication == nil { splitPublication = Date() }
            }
        }
        defer { withExtendedLifetime(publications) {} }

        let closeStart = Date()
        desk.objectAction(device: device.id, method: "pane.close", params: ["pane_id": .string("right")])
        try await wait { desk.sessions[device.id]?.panes.contains(where: { $0.id == "right" }) == false }
        let closeStateTime = Date().timeIntervalSince(closeStart)
        render()
        let closeTime = Date().timeIntervalSince(closeStart)
        print("NATIVE CLOSE STAGES: state=\(closeStateTime)s layout=\(closeTime - closeStateTime)s total=\(closeTime)s")
        print("NATIVE CLOSE PUBLICATION: \(closePublication?.timeIntervalSince(closeStart) ?? -1)s")
        wire.trace(since: closeStart)
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
        print("NATIVE SPLIT PUBLICATION: \(splitPublication?.timeIntervalSince(splitStart) ?? -1)s")
        wire.trace(since: splitStart)
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

    @Test func metadataAndNavigationReuseLayoutWithoutReplacingTerminals() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("hx-navigation-" + UUID().uuidString)
        let previous = ProcessInfo.processInfo.environment["HERDRX_STATE_DIR"]
        setenv("HERDRX_STATE_DIR", root.path, 1)
        defer {
            if let previous { setenv("HERDRX_STATE_DIR", previous, 1) } else { unsetenv("HERDRX_STATE_DIR") }
            try? FileManager.default.removeItem(at: root)
        }
        let wire = PaneActionWire()
        let server = try TestRPCServer(requests: 200, concurrent: true, fragmentSize: 65536, rawHandler: wire.respond)
        let desk = Desk(startServices: false)
        defer { desk.shutdown(); wire.stopEvents.signal(); withExtendedLifetime(server) {} }
        desk.add(Device(id: "fixture", displayName: "Isolated navigation", endpoint: .init(kind: "local", socketPath: server.path)))
        try await wait { desk.sessions["fixture"] != nil && desk.dividers.count == 1 }
        let key = PaneKey(device: "fixture", pane: "left")
        let terminal = try #require(desk.terminals[key])
        let attachment = terminal.attachmentID, reads = wire.layoutExports
        var fields = wire.snapshot.object
        fields["panes"] = .array(fields["panes"]!.array.map { pane in
            var value = pane.object
            value["agent"] = .string("codex"); value["agent_status"] = .string("idle")
            value["title"] = .string("Synthetic metadata changed")
            return .object(value)
        })
        fields["layouts"] = .array(fields["layouts"]!.array.map { layout in
            var value = layout.object; value["focused_pane_id"] = .string("right")
            value["panes"] = .array(value["panes"]!.array.map { pane in
                var leaf = pane.object; leaf["focused"] = .bool(true); return .object(leaf)
            })
            return .object(value)
        })
        desk.sessions["fixture"] = try Session(.object(fields)); desk.reindex()
        for _ in 0..<20 { desk.ensureAttachments() }
        desk.activityFilter = .working
        #expect(desk.visibleSpaces("fixture").map(\.id) == ["w"], "Current Space must remain even when idle")
        #expect(desk.focused == key && desk.terminals[key] === terminal)
        try await Task.sleep(for: .milliseconds(100))
        #expect(wire.layoutExports == reads, "Metadata/filter changes repeated layout.export")
        desk.select(device: "fixture", space: "other", tab: "other-t")
        try await wait { wire.layoutExports == reads + 1 }
        try await Task.sleep(for: .milliseconds(100))
        desk.select(device: "fixture", space: "w", tab: "t")
        try await Task.sleep(for: .milliseconds(100))
        #expect(wire.layoutExports == reads + 1, "Returning to cached tab repeated layout.export")
        #expect(desk.terminals[key] === terminal && terminal.attachmentID == attachment)
        desk.canvasSize = CGSize(width: 1000, height: 800)
        desk.setRatio(try #require(desk.dividers.first), ratio: 0.6)
        try await wait { desk.dividers.first?.ratio == 0.6 }
        #expect(wire.layoutExports == reads + 2, "Explicit ratio write must refresh the tree even when cell rectangles are unchanged")
        let right = PaneKey(device: "fixture", pane: "right")
        desk.detachClosedPane(right)
        #expect(desk.terminals[right] == nil && desk.dividers.isEmpty)
        desk.restoreDetachedPane(right)
        try await wait { desk.terminals[right] != nil && desk.dividers.first?.panes == Set([key, right]) }
        #expect(wire.layoutExports == reads + 3, "Rejected optimistic close must restore the authoritative tree")
        #expect(desk.terminals[key] === terminal && terminal.attachmentID == attachment)
        print("NATIVE LAYOUT: 20 metadata reconciliations + filter + return navigation reused cached export and terminal attachment")
    }

    @Test func contextualCreationCapturesSpaceAndRecoversFromFailureAndStalePane() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("hx-create-" + UUID().uuidString)
        let previous = ProcessInfo.processInfo.environment["HERDRX_STATE_DIR"]
        setenv("HERDRX_STATE_DIR", root.path, 1)
        defer {
            if let previous { setenv("HERDRX_STATE_DIR", previous, 1) } else { unsetenv("HERDRX_STATE_DIR") }
            try? FileManager.default.removeItem(at: root)
        }
        let wire = PaneActionWire()
        let server = try TestRPCServer(requests: 200, concurrent: true, fragmentSize: 65536, rawHandler: wire.respond)
        let desk = Desk(startServices: false)
        defer { desk.shutdown(); wire.stopEvents.signal(); withExtendedLifetime(server) {} }
        desk.add(Device(id: "fixture", displayName: "Isolated creation", endpoint: .init(kind: "local", socketPath: server.path)))
        try await wait { desk.sessions["fixture"] != nil }
        let focus = desk.focused
        desk.create(device: "fixture", space: "other")
        try await wait { !desk.busy.contains(desk.creationID("fixture", "other")) }
        #expect(wire.tabCreations.count == 1)
        #expect(wire.tabCreations.first?["workspace_id"].string == "other")
        #expect(wire.tabCreations.first?["cwd"].string == "/tmp")
        #expect(wire.tabCreations.first?["focus"] == .bool(false))
        #expect(desk.message != nil && desk.focused == focus, "Rejected creation must keep the usable terminal")
        desk.message = nil
        desk.create(device: "fixture", space: "other")
        // Remove the captured pane while pane.get is in flight.
        var snapshot = wire.snapshot.object
        snapshot["panes"] = .array(snapshot["panes"]!.array.filter { $0["workspace_id"].string != "other" })
        desk.sessions["fixture"] = try Session(.object(snapshot))
        try await wait { !desk.busy.contains(desk.creationID("fixture", "other")) }
        #expect(wire.tabCreations.count == 1, "Stale target must not send tab.create")
        #expect(desk.message != nil && desk.focused == focus)
    }

    @Test func wheelSamplesArrivingDuringPreflightJoinTheCurrentBatch() async throws {
        let terminal = Terminal(command: "/bin/cat", takeoverCommand: "/bin/cat", observationCommand: { _, _ in "/bin/cat" })
        defer { terminal.stop() }
        var batches = 0, samples = 0
        terminal.onScroll = { [weak terminal] events in
            batches += 1
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, let terminal else { return }
            samples += events.count + terminal.takePendingScrollEvents().count
        }
        let cg = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0))
        let event = try #require(NSEvent(cgEvent: cg))
        terminal.view.onRemoteScroll?(event)
        try await wait { batches == 1 }
        terminal.view.onRemoteScroll?(event); terminal.view.onRemoteScroll?(event)
        try await wait { samples == 3 }
        #expect(batches == 1, "Queued gesture samples started another preflight")
        #expect(terminal.takePendingScrollEvents().isEmpty)
    }

    private func wait(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(condition(), "Timed out waiting for native pane action")
    }
}
