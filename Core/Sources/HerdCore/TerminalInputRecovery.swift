import Foundation

public enum TerminalInputRecovery {
    // Local emulator control bytes, never sent as input to the server PTY.
    // Leave screen, scrollback and the shell's bracketed-paste mode intact.
    public static let keyboardBytes = Data("\u{1b}[<99u\u{1b}[=0u\u{1b}[>4;0m\u{1b}[?1004l".utf8)
    public static let bytes = keyboardBytes + Data(
        [1000, 1001, 1002, 1003, 1005, 1006, 1015, 1016].map { "\u{1b}[?\($0)l" }.joined().utf8)
    public static func isIdleShell(_ info: JSON, pane: String) -> Bool {
        guard info["pane_id"].string == pane, let shell = info["shell_pid"].int, shell > 0,
              info["foreground_process_group_id"].int == shell else { return false }
        let processes = info["foreground_processes"].array
        return !processes.isEmpty && processes.allSatisfy { process in
            let name = (process["name"].string ?? "").split(separator: "/").last.map(String.init) ?? ""
            return process["pid"].int == shell && ["sh", "bash", "zsh", "fish", "dash", "ksh", "tcsh", "csh"].contains(name)
        }
    }
}

/// Observe only keyboard-mode negotiation, without rewriting terminal output.
/// A fresh monitor belongs to one attachment; reads may split any CSI sequence.
public final class TerminalKeyboardMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [UInt8] = []
    public init() {}

    public func append(_ data: Data) -> Bool {
        lock.lock(); defer { lock.unlock() }
        var enabled = false
        for byte in data {
            if byte == 0x1b { pending = [byte]; continue }
            guard !pending.isEmpty else { continue }
            if pending.count == 1 {
                if byte == 0x5b { pending.append(byte) } else { pending.removeAll(keepingCapacity: true) }
                continue
            }
            if (0x40...0x7e).contains(byte) {
                let parameters = String(decoding: pending.dropFirst(2), as: UTF8.self)
                if byte == 0x75, parameters.first == ">" || parameters.first == "=" {
                    let flags = parameters.dropFirst().split(separator: ";").first.flatMap { Int($0) } ?? 0
                    // CSI = flags;3u removes flags rather than enabling them.
                    let mode = parameters.dropFirst().split(separator: ";").dropFirst().first
                    enabled = enabled || (flags > 0 && (parameters.first == ">" || mode != "3"))
                } else if byte == 0x6d, [">4;1", ">4;2"].contains(parameters) {
                    enabled = true
                }
                pending.removeAll(keepingCapacity: true)
            } else if (0x20...0x3f).contains(byte), pending.count < 64 {
                pending.append(byte)
            } else {
                pending.removeAll(keepingCapacity: true)
            }
        }
        return enabled
    }
}
