import Foundation

public struct Device: Codable, Identifiable, Equatable, Sendable {
    public struct Endpoint: Codable, Equatable, Sendable {
        public var kind: String
        public var target: String?
        public var port: Int?
        public var socketPath: String
        public var sshConfig: String?
        public init(kind: String, target: String? = nil, port: Int? = nil, socketPath: String, sshConfig: String? = nil) {
            self.kind = kind; self.target = target; self.port = port; self.socketPath = socketPath; self.sshConfig = sshConfig
        }
    }
    public var id: String
    public var displayName: String
    public var endpoint: Endpoint
    public init(id: String = UUID().uuidString, displayName: String, endpoint: Endpoint) {
        self.id = id; self.displayName = displayName; self.endpoint = endpoint
    }
}

public struct PaneKey: Codable, Hashable, Sendable {
    public let device: String
    public let pane: String
    public init(device: String, pane: String) { self.device = device; self.pane = pane }
}
