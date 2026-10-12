import Foundation

private final class ByteCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var bytes = Data()
    func append(_ data: Data) { lock.lock(); bytes.append(data); lock.unlock() }
    func contains(_ text: String) -> Bool { lock.lock(); defer { lock.unlock() }; return String(decoding: bytes, as: UTF8.self).contains(text) }
}

@main @MainActor struct TerminalCoexistence {
    static func wait(_ label: String, until condition: () async throws -> Bool) async throws {
        for _ in 0..<100 {
            if try await condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw Failure("Timed out: " + label)
    }
    static func main() async throws {
        let args = CommandLine.arguments
        let socket = args[1], target = args[2], pane = args[3], directory = args[4]
        let endpoint = Device.Endpoint(kind: "local", socketPath: socket)
        // A login shell may reorder PATH; select the fixture binary explicitly.
        func command(_ mode: TerminalAttachment.Mode) -> String { "export PATH=" + quote(directory + "/bin") + ":\"$PATH\"; " + TerminalAttachment.command(endpoint: endpoint, socket: socket, terminal: target, mode: mode) }
        let client = RPC(path: socket)
        let first = ByteProcess(), second = ByteProcess(), third = ByteProcess(), observer = TerminalObservation()
        defer { first.stop(); second.stop(); third.stop(); observer.stop() }
        let output = ByteCapture(), secondOutput = ByteCapture(), observed = ByteCapture()
        var firstExited = false, secondExited = false, observerEnded = false
        first.output = { output.append($0) }; second.output = { secondOutput.append($0) }
        first.exited = { _ in firstExited = true }
        second.exited = { _ in secondExited = true }
        observer.output = { observed.append($0) }; observer.ended = { _ in observerEnded = true }
        let before = try await client.call("pane.process_info", ["pane_id": .string(pane)])["process_info"]
        first.start(command(.control))
        try await Task.sleep(for: .milliseconds(700)); first.resize(97, 31)
        first.write(Data("printf 'READY_OWNER\\n'\n".utf8))
        try await wait("first controller input") { output.contains("READY_OWNER") }
        second.start(command(.control))
        try await wait("ordinary second attach is rejected") { secondExited && secondOutput.contains("already has an attached client") }
        guard !firstExited, secondOutput.contains("already has an attached client") else { throw Failure("Second attachment displaced the owner") }
        second.stop()
        let observe: (UInt16, UInt16) -> String = { cols, rows in TerminalAttachment.command(endpoint: endpoint, socket: socket, terminal: target, mode: .observe, columns: cols, rows: rows) }
        observer.start(observe)
        try await wait("observer initial frame") { observed.contains("READY_OWNER") }
        observer.resize(120, 40)
        try await Task.sleep(for: .milliseconds(400))
        let sizeFile = directory + "/pty-size"
        first.write(Data(("stty size > " + quote(sizeFile) + "; printf 'LIVE_OBSERVER\\n'\n").utf8))
        try await wait("observer updates") { observed.contains("LIVE_OBSERVER") }
        try await wait("owner size result") { FileManager.default.fileExists(atPath: sizeFile) }
        let size = try String(contentsOfFile: sizeFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard size == "31 97", !firstExited, !observerEnded else { throw Failure("Observer changed owner size or ended: \(size)") }
        for _ in 0..<3 { observer.stop(); observer.start(observe); observer.resize(101, 35) }
        try await Task.sleep(for: .milliseconds(400))
        observer.stop()
        guard !firstExited, !observerEnded else { throw Failure("Observer restart affected controller") }
        first.write(Data("sleep 15\n".utf8))
        try await wait("foreground process") {
            let info = try await client.call("pane.process_info", ["pane_id": .string(pane)])["process_info"]
            return info["foreground_process_group_id"] != before["shell_pid"] && !TerminalInputRecovery.isIdleShell(info, pane: pane)
        }
        first.write(Data([3]))
        try await wait("verified shell after interrupt") {
            TerminalInputRecovery.isIdleShell(try await client.call("pane.process_info", ["pane_id": .string(pane)])["process_info"], pane: pane)
        }
        secondExited = false; second.start(command(.takeover))
        try await wait("explicit takeover") { firstExited }
        let marker = directory + "/takeover-input"
        second.write(Data(("printf OK > " + quote(marker) + "\n").utf8))
        try await wait("new owner input") { FileManager.default.fileExists(atPath: marker) }
        second.stop(); observer.start(observe)
        try await Task.sleep(for: .milliseconds(300))
        third.start(command(.control))
        try await Task.sleep(for: .milliseconds(500))
        let thirdMarker = directory + "/third-input"
        third.write(Data(("printf OK > " + quote(thirdMarker) + "\n").utf8))
        try await wait("observer never owns input") { FileManager.default.fileExists(atPath: thirdMarker) }
        let after = try await client.call("pane.process_info", ["pane_id": .string(pane)])["process_info"]
        guard before["shell_pid"] == after["shell_pid"] else { throw Failure("Server shell changed") }
        print("PASS: production PTY attach refuses takeover; observer streams/resizes/restarts without stealing input or resizing owner; explicit takeover; detach preserves shell PID; actual foreground shell guard")
    }
}
