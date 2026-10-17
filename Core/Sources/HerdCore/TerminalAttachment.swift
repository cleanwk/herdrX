import Foundation

/// Herdr's existing CLI contracts. Taking ownership is always an explicit mode.
public enum TerminalAttachment {
    public enum Mode { case control, takeover, observe }
    public static func command(endpoint: Device.Endpoint, socket: String, terminal: String, mode: Mode, columns: UInt16 = 80, rows: UInt16 = 24) -> String {
        let args = mode == .observe ? "terminal session observe " + quote(terminal) + " --cols \(columns) --rows \(rows)"
            : "terminal attach " + quote(terminal) + (mode == .takeover ? " --takeover" : "")
        let script = "export HERDR_SOCKET_PATH=" + quote(socket) + "; exec herdr " + args
        guard endpoint.kind == "ssh" else { return script }
        return "exec /usr/bin/ssh " + (endpoint.sshConfig.map { "-F " + quote($0) + " " } ?? "")
            + (mode == .observe ? "-T " : "-tt ") + (endpoint.port.map { "-p \($0) " } ?? "")
            + quote(endpoint.target ?? "") + " "
            + quote("/bin/sh -lc " + quote("export PATH=\"$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH\"; " + script))
    }
}

/// Decode only documented terminal-session envelopes, never terminal text as JSON.
public struct TerminalFrameDecoder {
    private var lines = LineBuffer(limit: 16 * 1024 * 1024)
    private let decoder = JSONDecoder()
    private var sequence: Int?
    public private(set) var closedReason: String?
    public init() {}
    public mutating func append(_ data: Data) throws -> [Data] {
        try lines.append(data).compactMap { line in
            let value = try decoder.decode(JSON.self, from: line)
            if value["type"].string == "terminal.closed" {
                closedReason = value["reason"].string ?? "Terminal observation ended"
                return nil
            }
            guard value["type"].string == "terminal.frame", value["encoding"].string == "ansi",
                  let next = value["seq"].int, let text = value["bytes"].string,
                  let bytes = Data(base64Encoded: text),
                  (value["width"].int ?? 0) > 0, (value["height"].int ?? 0) > 0,
                  sequence.map({ next > $0 }) ?? (value["full"].bool == true) else {
                throw Failure("Invalid terminal observation frame")
            }
            sequence = next
            return bytes
        }
    }
}
