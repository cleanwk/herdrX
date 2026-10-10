import Foundation

public struct ConnectionDraft: Equatable, Sendable {
    public var id: String?
    public var name = ""
    public var target = ""
    public var socket = ""
    public var port = ""
    public var sshConfig = ""
    public var local = false
    public init(_ device: Device? = nil) {
        guard let device else { return }
        id = device.id; name = device.displayName; target = device.endpoint.target ?? ""; socket = device.endpoint.socketPath
        port = device.endpoint.port.map(String.init) ?? ""; sshConfig = device.endpoint.sshConfig ?? ""; local = device.endpoint.kind == "local"
    }
    public func device() throws -> Device {
        guard let name = DisplayTitle.clean(name), socket.hasPrefix("/"), !socket.contains(where: { $0.isNewline || $0 == "\0" || $0 == ":" }),
              local || (!target.isEmpty && !target.hasPrefix("-") && !target.contains(where: \.isWhitespace)),
              local || port.isEmpty || Int(port).map({ (1...65535).contains($0) }) == true,
              local || sshConfig.isEmpty || (sshConfig.hasPrefix("/") && !sshConfig.contains(where: { $0.isNewline || $0 == "\0" })) else { throw Failure("Invalid connection draft") }
        return Device(id: id ?? UUID().uuidString, displayName: name, endpoint: .init(kind: local ? "local" : "ssh", target: local ? nil : target, port: local ? nil : Int(port), socketPath: socket, sshConfig: local || sshConfig.isEmpty ? nil : sshConfig))
    }
}
