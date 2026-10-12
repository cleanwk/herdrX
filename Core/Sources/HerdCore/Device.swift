import Foundation

public struct Device: Codable, Identifiable, Equatable, Sendable {
    public struct Endpoint: Codable, Equatable, Sendable {
        public var kind: String
        public var target: String?
        public var port: Int?
        public var socketPath: String
        public var sshConfig: String?
        public var session: String?
        public init(kind: String, target: String? = nil, port: Int? = nil, socketPath: String = "", sshConfig: String? = nil, session: String? = nil) {
            self.kind = kind; self.target = target; self.port = port; self.socketPath = socketPath; self.sshConfig = sshConfig; self.session = session
        }
        private enum CodingKeys: String, CodingKey { case kind, target, port, socketPath, sshConfig, session }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kind = try c.decode(String.self, forKey: .kind); target = try c.decodeIfPresent(String.self, forKey: .target)
            port = try c.decodeIfPresent(Int.self, forKey: .port); socketPath = try c.decodeIfPresent(String.self, forKey: .socketPath) ?? ""
            sshConfig = try c.decodeIfPresent(String.self, forKey: .sshConfig); session = try c.decodeIfPresent(String.self, forKey: .session)
        }
        public static func validSocket(_ value: String) -> Bool { value.hasPrefix("/") && !value.contains(where: { $0.isNewline || $0 == "\0" || $0 == ":" }) }
        public static func validTarget(_ value: String) -> Bool { !value.isEmpty && !value.hasPrefix("-") && !value.contains(where: { $0.isWhitespace || $0 == "\0" }) }
        public static func validSession(_ value: String) -> Bool {
            !value.isEmpty && value.utf8.count <= 64 && value != "." && value != ".." && value.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-").contains($0) }
        }
        public var valid: Bool {
            guard ["local", "ssh", "tailcat"].contains(kind) else { return false }
            if kind != "ssh" { return Self.validSocket(socketPath) }
            return Self.validTarget(target ?? "") && (port == nil || (1...65535).contains(port!))
                && (sshConfig == nil || (sshConfig!.hasPrefix("/") && !sshConfig!.contains(where: { $0.isNewline || $0 == "\0" })))
                && (session.map(Self.validSession) ?? Self.validSocket(socketPath))
        }
    }
    public var id: String
    public var displayName: String
    public var endpoint: Endpoint
    public var source: String?
    public var herdrProfile: String? { source.flatMap { $0.hasPrefix("herdr-machine:") ? String($0.dropFirst("herdr-machine:".count)) : nil } }
    public init(id: String = UUID().uuidString, displayName: String, endpoint: Endpoint, source: String? = nil) {
        self.id = id; self.displayName = displayName; self.endpoint = endpoint; self.source = source
    }
    private enum CodingKeys: String, CodingKey { case id, displayName, endpoint, source }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); displayName = try c.decode(String.self, forKey: .displayName); endpoint = try c.decode(Endpoint.self, forKey: .endpoint)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        // Migrate only files written before explicit ownership existed. New
        // manual devices encode source:null, even if their ID resembles ours.
        if !c.contains(.source), endpoint.kind == "ssh", id.hasPrefix("herdr-machine."), id.count > "herdr-machine.".count { source = "herdr-machine:" + id.dropFirst("herdr-machine.".count) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(displayName, forKey: .displayName); try c.encode(endpoint, forKey: .endpoint); try c.encode(source, forKey: .source)
    }
}

public struct PaneKey: Codable, Hashable, Sendable {
    public let device: String
    public let pane: String
    public init(device: String, pane: String) { self.device = device; self.pane = pane }
}
