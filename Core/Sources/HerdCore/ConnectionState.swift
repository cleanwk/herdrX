import Foundation
import Darwin

/// Preserve the socket failure code so recovery never depends on translated error text.
public struct SocketConnectionError: LocalizedError, Sendable {
    public let path: String
    public let code: Int32
    public init(path: String, code: Int32) { self.path = path; self.code = code }
    public var errorDescription: String? { "Cannot connect to \(path): \(String(cString: strerror(code)))" }
}

/// Only canonical Herdr session paths can be mapped back to a CLI launch safely.
public struct LocalHerdrTarget: Equatable, Sendable {
    public let session: String?
    public init?(endpoint: Device.Endpoint, home: String = NSHomeDirectory()) {
        guard endpoint.kind == "local" else { return nil }
        let root = home + "/.config/herdr"
        if endpoint.socketPath == root + "/herdr.sock" { session = nil; return }
        let prefix = root + "/sessions/", suffix = "/herdr.sock"
        guard endpoint.socketPath.hasPrefix(prefix), endpoint.socketPath.hasSuffix(suffix) else { return nil }
        let name = String(endpoint.socketPath.dropFirst(prefix.count).dropLast(suffix.count))
        guard !name.isEmpty, name.utf8.count <= 64, name != "default", name != ".", name != "..",
              name.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [45, 46, 95].contains($0) }) else { return nil }
        session = name
    }
    public var arguments: [String] { session.map { ["--session", $0, "server"] } ?? ["server"] }
}

public struct ConnectionIssue: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case localStopped, localUnavailable, authentication, unavailable, configuration, startFailed, notInstalled }
    public let kind: Kind
    public let detail: String
    public init(_ kind: Kind, detail: String) { self.kind = kind; self.detail = detail }
    public init(error: Error, endpoint: Device.Endpoint) {
        detail = error.localizedDescription
        if endpoint.kind == "local", let socket = error as? SocketConnectionError,
           socket.code == ENOENT || socket.code == ECONNREFUSED {
            kind = LocalHerdrTarget(endpoint: endpoint) == nil ? .localUnavailable : .localStopped
        } else if endpoint.kind == "ssh", detail.localizedCaseInsensitiveContains("permission denied") || detail.localizedCaseInsensitiveContains("host key verification failed") {
            kind = .authentication
        } else { kind = .unavailable }
    }
    public var title: String {
        switch kind {
        case .localStopped: "Herdr is not running"
        case .localUnavailable: "Session unavailable"
        case .authentication: "SSH sign-in required"
        case .unavailable: "Unable to connect"
        case .configuration: "Check connection settings"
        case .startFailed: "Herdr could not start"
        case .notInstalled: "Install Herdr to continue"
        }
    }
    public var guidance: String {
        switch kind {
        case .localStopped: "Start Herdr to open your local spaces."
        case .localUnavailable: "Start this session in Herdr, or check its path in Connections."
        case .authentication: "Connect to this host in Terminal, then retry."
        case .unavailable: "Check that Herdr is running on this device. We’ll reconnect automatically."
        case .configuration: "Review this device in Connections, then retry."
        case .startFailed: "Check the details, then try starting Herdr again."
        case .notInstalled: "Install the Herdr CLI, then return here to start it."
        }
    }
    public var canStart: Bool { kind == .localStopped || kind == .startFailed || kind == .notInstalled }
    public var automaticallyRetries: Bool { ![.authentication, .configuration].contains(kind) }
}

public enum ConnectionState: Equatable, Sendable {
    case connecting, starting, connected, failed(ConnectionIssue)
    public var title: String {
        switch self {
        case .connecting: "Connecting…"
        case .starting: "Starting Herdr…"
        case .connected: "Connected"
        case .failed(let issue): issue.title
        }
    }
    public var issue: ConnectionIssue? { if case .failed(let issue) = self { issue } else { nil } }
    public var isBusy: Bool { self == .connecting || self == .starting }
}
