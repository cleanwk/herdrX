import Foundation

public enum RemoteHerdr {
    public struct Status: Equatable, Sendable {
        public let running: Bool
        public let socket: String
        public init(_ data: Data) throws {
            let value = try JSONDecoder().decode(JSON.self, from: data)
            guard let running = value["running"].bool, let socket = value["socket"].string, Device.Endpoint.validSocket(socket) else { throw Failure("Invalid remote Herdr server status.") }
            self.running = running; self.socket = socket
        }
    }
    public static func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    public static func arguments(_ endpoint: Device.Endpoint, command: [String]) throws -> [String] {
        guard endpoint.kind == "ssh", endpoint.valid, let name = endpoint.session else { throw Failure("Invalid remote named session.") }
        let script = "unset HERDR_SOCKET_PATH HERDR_CONFIG_PATH HERDR_SESSION HERDR_SESSION_NAME; export PATH=\"$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH\"; exec herdr --session " + quote(name) + " " + command.map(quote).joined(separator: " ") + " </dev/null"
        return (endpoint.sshConfig.map { ["-F", $0] } ?? []) + ["-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=2"] + (endpoint.port.map { ["-p", String($0)] } ?? []) + [endpoint.target!, "/bin/sh -lc " + quote(script)]
    }
    public static func resolve(_ endpoint: Device.Endpoint, run: @Sendable ([String]) async throws -> Data = { try await CommandProcess.run("/usr/bin/ssh", $0, input: Data(), timeout: 20) }) async throws -> String {
        guard endpoint.session != nil else {
            guard endpoint.valid else { throw Failure("Invalid remote socket.") }; return endpoint.socketPath
        }
        let probe = try arguments(endpoint, command: ["status", "server", "--json"])
        let first = try Status(await run(probe))
        try Task.checkCancellation()
        if first.running { return first.socket }
        // Herdr bootstraps the named server through this bridge and exits on EOF.
        _ = try await run(arguments(endpoint, command: ["remote-client-bridge"]))
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            try Task.checkCancellation()
            let next = try Status(await run(probe))
            if next.running { return next.socket }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw Failure("Remote Herdr did not become ready.")
    }
}
