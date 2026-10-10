import Foundation

/// The existing Herdr v1 contract. Commands are displayed, never executed by the GUI.
public struct ExtensionInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let enabled: Bool
    public let description: String
    public let warnings: [String]
    public let actions: [JSON]
    public let panes: [JSON]
    public init(_ value: JSON) throws {
        guard let id = value["plugin_id"].string, let name = value["name"].string, let version = value["version"].string, let enabled = value["enabled"].bool else { throw Failure("Incomplete Herdr plugin record") }
        self.id = id; self.name = name; self.version = version; self.enabled = enabled
        description = value["description"].string ?? ""
        warnings = value["warnings"].array.compactMap(\.string)
        actions = value["actions"].array; panes = value["panes"].array
    }
}
public enum Extensions {
    public static func list(_ rpc: RPC) async throws -> [ExtensionInfo] {
        let result = try await rpc.call("plugin.list")
        guard case .array = result["plugins"] else { throw Failure("Herdr did not return a plugin list") }
        return try result["plugins"].array.map(ExtensionInfo.init)
    }
    public static func invoke(_ rpc: RPC, plugin: String, action: String, context: [String: JSON]) async throws -> JSON {
        try await rpc.call("plugin.action.invoke", ["plugin_id": .string(plugin), "action_id": .string(action), "context": .object(context)])
    }
    public static func setEnabled(_ rpc: RPC, plugin: String, enabled: Bool) async throws {
        _ = try await rpc.call(enabled ? "plugin.enable" : "plugin.disable", ["plugin_id": .string(plugin)])
    }
    public static func open(_ rpc: RPC, plugin: String, entry: String, workspace: String?) async throws -> JSON {
        // Herdr supports this placement override; a tab has an attachable pane ID.
        var params: [String: JSON] = ["plugin_id": .string(plugin), "entrypoint": .string(entry), "placement": .string("tab"), "focus": .bool(false)]
        if let workspace { params["workspace_id"] = .string(workspace) }
        return try await rpc.call("plugin.pane.open", params)
    }
}
