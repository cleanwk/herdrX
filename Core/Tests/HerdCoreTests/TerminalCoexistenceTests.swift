import XCTest
@testable import HerdCore

final class TerminalCoexistenceTests: XCTestCase {
    private func json(_ text: String) throws -> JSON { try JSONDecoder().decode(JSON.self, from: Data(text.utf8)) }
    func testOwnershipAndRemoteTransportAreExplicit() {
        for kind in ["local", "ssh", "tailcat"] {
            let endpoint = Device.Endpoint(kind: kind, target: "user@host", port: 2222, socketPath: "/tmp/a ' socket", sshConfig: "/tmp/ssh config")
            let normal = TerminalAttachment.command(endpoint: endpoint, socket: endpoint.socketPath, terminal: "terminal-1", mode: .control)
            let observe = TerminalAttachment.command(endpoint: endpoint, socket: endpoint.socketPath, terminal: "terminal-1", mode: .observe, columns: 93, rows: 31)
            let takeover = TerminalAttachment.command(endpoint: endpoint, socket: endpoint.socketPath, terminal: "terminal-1", mode: .takeover)
            XCTAssertFalse(normal.contains("--takeover")); XCTAssertFalse(observe.contains("--takeover"))
            XCTAssertTrue(takeover.contains("--takeover")); XCTAssertTrue(observe.contains("--cols 93 --rows 31"))
            if kind == "ssh" { XCTAssertTrue(normal.contains("-tt ")); XCTAssertTrue(observe.contains("-T ")); XCTAssertFalse(observe.contains("-tt ")) }
        }
    }
    func testObserverFramesFragmentationAndValidation() throws {
        let first = "{\"type\":\"terminal.frame\",\"seq\":1,\"encoding\":\"ansi\",\"width\":80,\"height\":24,\"full\":true,\"bytes\":\"5Lit5paH\"}\n"
        let next = first.replacingOccurrences(of: "\"seq\":1", with: "\"seq\":2").replacingOccurrences(of: "true", with: "false")
        var decoder = TerminalFrameDecoder()
        let bytes = Data(first.utf8)
        XCTAssertEqual(try decoder.append(bytes.prefix(23)), [])
        XCTAssertEqual(try decoder.append(bytes.dropFirst(23) + Data(next.utf8)), [Data("中文".utf8), Data("中文".utf8)])
        XCTAssertThrowsError(try decoder.append(Data(next.utf8)))
        var missingInitial = TerminalFrameDecoder()
        XCTAssertThrowsError(try missingInitial.append(Data(next.utf8)))
        var invalid = TerminalFrameDecoder()
        XCTAssertThrowsError(try invalid.append(Data(first.replacingOccurrences(of: "5Lit5paH", with: "!").utf8)))
        var closed = TerminalFrameDecoder()
        XCTAssertEqual(try closed.append(Data("{\"type\":\"terminal.closed\",\"reason\":\"closed\"}\n".utf8)), [])
        XCTAssertEqual(closed.closedReason, "closed")
    }
    func testAuthoritativeAgentsAndLegacyFallback() throws {
        let base = try json(#"{"workspaces":[{"workspace_id":"w"}],"tabs":[{"workspace_id":"w","tab_id":"t"}],"panes":[{"workspace_id":"w","tab_id":"t","pane_id":"p","terminal_id":"term","agent":"codex","cwd":"/work/project"}]}"#)
        XCTAssertEqual(try Session(base).agents.count, 1)
        var value = base.object
        value["agents"] = .array([])
        XCTAssertTrue(try Session(.object(value)).agents.isEmpty, "An explicit empty authoritative list must not revive a stale pane agent")
        let record = try json(#"{"workspace_id":"w","tab_id":"t","pane_id":"p","terminal_id":"term","agent":null,"name":"Review task","agent_session":{"agent":"claude"}}"#)
        value["agents"] = .array([record])
        let session = try Session(.object(value))
        XCTAssertEqual(session.agents.first?.agent, "claude")
        XCTAssertEqual(session.agents.first?.cwd, "/work/project")
        XCTAssertEqual(session.agents.first?.sessionName, "Review task")
        var foreign = record.object; foreign["terminal_id"] = .string("replaced")
        value["agents"] = .array([.object(foreign)])
        XCTAssertTrue(try Session(.object(value)).agents.isEmpty)
        value["agents"] = .array([record, record])
        XCTAssertThrowsError(try Session(.object(value)))
    }
    func testAgentRowKeepsTaskButDoesNotRepeatBrand() throws {
        let base = try json(#"{"pane_id":"p","agent":"codex","title":"codex","cwd":"/work/project"}"#)
        let item = try Item(base, kind: "pane")
        XCTAssertEqual(DisplayTitle.agentRow(item, tab: nil, fallback: "Untitled Task"), "project")
        var fields = base.object; fields["label"] = .string("Codex migration")
        XCTAssertEqual(DisplayTitle.agentRow(try Item(.object(fields), kind: "pane"), tab: nil, fallback: "Task"), "Codex migration")
        fields["label"] = .string("Codex")
        XCTAssertEqual(DisplayTitle.agentRow(try Item(.object(fields), kind: "pane"), tab: nil, fallback: "Task"), "project")
    }
    func testRecoveryRequiresVerifiedForegroundShell() throws {
        let info = try json(#"{"pane_id":"p","shell_pid":42,"foreground_process_group_id":42,"foreground_processes":[{"pid":42,"name":"/bin/zsh"}]}"#)
        XCTAssertTrue(TerminalInputRecovery.isIdleShell(info, pane: "p"))
        XCTAssertFalse(TerminalInputRecovery.isIdleShell(info, pane: "other"))
        XCTAssertFalse(TerminalInputRecovery.isIdleShell(.null, pane: "p"))
        var fields = info.object; fields["foreground_process_group_id"] = .number(43)
        XCTAssertFalse(TerminalInputRecovery.isIdleShell(.object(fields), pane: "p"))
        fields = info.object; fields["foreground_processes"] = .array([])
        XCTAssertFalse(TerminalInputRecovery.isIdleShell(.object(fields), pane: "p"))
        fields["foreground_processes"] = .array([.object(["pid": .number(42), "name": .string("codex")])])
        XCTAssertFalse(TerminalInputRecovery.isIdleShell(.object(fields), pane: "p"), "exec-ed agent keeps the shell PID")
    }
    func testKeyboardNegotiationIsDetectedAcrossEveryReadBoundary() {
        for sequence in ["\u{1b}[>7u", "\u{1b}[>31u", "\u{1b}[=3u", "\u{1b}[=3;2u", "\u{1b}[>4;1m", "\u{1b}[>4;2m"] {
            let bytes = Data(sequence.utf8)
            for split in 0...bytes.count {
                let monitor = TerminalKeyboardMonitor()
                let first = monitor.append(bytes.prefix(split))
                let second = monitor.append(bytes.dropFirst(split))
                XCTAssertTrue(first || second, "Missed negotiation at boundary \(split): \(sequence.debugDescription)")
                XCTAssertFalse(first && second, "One sequence should trigger once")
            }
        }
        let monitor = TerminalKeyboardMonitor()
        XCTAssertTrue(monitor.append(Data("frame\u{1b}[>7u\u{1b}[?1003h\u{1b}[?1006h".utf8)))
        XCTAssertFalse(monitor.append(Data("next frame".utf8)))
    }
    func testKeyboardMonitorIgnoresResetsTextAndMalformedSequences() {
        let monitor = TerminalKeyboardMonitor()
        for text in ["99;5u99;5:3u", "[>7u", "\u{1b}[?u", "\u{1b}[>0u", "\u{1b}[=0u", "\u{1b}[=3;3u", "\u{1b}[<99u", "\u{1b}[>4;0m", "\u{1b}[?1003h", "\u{1b}[31m", "\u{1b}[>7\nu", "\u{1b}[>" + String(repeating: "1", count: 100) + "u"] {
            XCTAssertFalse(monitor.append(Data(text.utf8)), text.debugDescription)
        }
        XCTAssertTrue(monitor.append(Data("\u{1b}[broken\u{1b}[>7u".utf8)), "A malformed sequence must not hide a later negotiation")
    }
}
