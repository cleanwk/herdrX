import Foundation

/// Presentation only: saved connections retain their identity and ownership.
public struct DeviceNavigationGroup: Identifiable, Equatable, Sendable {
    public let devices: [Device]
    public var id: String { devices[0].id }
    public func contains(_ id: String) -> Bool { devices.contains { $0.id == id } }
    public func representative(selected: String?, connected: Set<String>) -> Device {
        // Never move the user's mounted terminal to a different connection.
        devices.first { $0.id == selected } ?? devices.first { connected.contains($0.id) } ?? devices[0]
    }
    public static func groups(_ devices: [Device], resolvedSockets: [String: String]) -> [Self] {
        struct Endpoint: Hashable {
            let kind: String
            let target: String?
            let port: Int?
            let config: String?
            let socket: String
        }
        var groups: [[Device]] = [], indices: [Endpoint: Int] = [:]
        for device in devices {
            let endpoint = device.endpoint
            // A named session is not equivalent to a configured socket until
            // the existing connection resolver confirms the actual socket.
            let socket = resolvedSockets[device.id] ?? (endpoint.session == nil ? endpoint.socketPath : "")
            guard ["local", "ssh"].contains(endpoint.kind), Device.Endpoint.validSocket(socket) else {
                groups.append([device]); continue
            }
            let key = Endpoint(kind: endpoint.kind, target: endpoint.target, port: endpoint.port, config: endpoint.sshConfig, socket: socket)
            if let index = indices[key] { groups[index].append(device) }
            else { indices[key] = groups.count; groups.append([device]) }
        }
        return groups.map { Self(devices: $0) }
    }
}

public enum AgentActivityFilter: String, CaseIterable, Sendable {
    case all, working, attention
    public var title: String {
        switch self { case .all: "All Activity"; case .working: "Working"; case .attention: "Needs Attention" }
    }
    public func includes(status: String, needsAttention: Bool) -> Bool {
        switch self { case .all: true; case .working: status == "working"; case .attention: needsAttention }
    }
}
