import Foundation

/// An authoritative, local-only catalog. An unreadable/ambiguous snapshot must
/// never be interpreted as an empty catalog.
public struct HerdrMachines: Sendable {
    public let devices: [Device]
    public let retainedProfiles: Set<String>
    public let warnings: [String]
    public init(data: Data) throws {
        let value = try JSONDecoder().decode(JSON.self, from: data)
        guard case .array(let rows) = value else { throw Failure("Invalid Herdr machine list.") }
        var devices: [Device] = [], seen = Set<String>(), retained = Set<String>(), warnings: [String] = []
        for row in rows {
            guard let id = row["id"].string, !id.isEmpty, seen.insert(id).inserted else { throw Failure("Herdr machine list has missing or duplicate IDs.") }
            guard case .bool(let enabled) = row["enabled"] else { retained.insert(id); warnings.append(id); continue }
            if !enabled { continue }
            guard let label = row["label"].string.flatMap(DisplayTitle.clean), let target = row["target"].string,
                  let session = row["session"].string, Device.Endpoint.validTarget(target), Device.Endpoint.validSession(session) else {
                retained.insert(id); warnings.append(id); continue
            }
            devices.append(Device(id: "herdr-machine." + id, displayName: label, endpoint: .init(kind: "ssh", target: target, session: session), source: "herdr-machine:" + id))
        }
        self.devices = devices; retainedProfiles = retained; self.warnings = warnings
    }
    public struct Changes: Sendable {
        public var added: [Device] = []
        public var updated: [Device] = []
        public var removed: [String] = []
    }
    public func changes(to existing: [Device], removeMissing: Bool = true) -> Changes {
        var result = Changes()
        let desired = Dictionary(uniqueKeysWithValues: devices.map { ($0.source!, $0) })
        for old in existing {
            guard let profile = old.herdrProfile else { continue }
            if var new = desired[old.source!] {
                new.id = old.id
                if new != old { result.updated.append(new) }
            } else if removeMissing, !retainedProfiles.contains(profile) { result.removed.append(old.id) }
        }
        for var new in devices where !existing.contains(where: { $0.source == new.source }) {
            if existing.contains(where: { $0.id == new.id }) { new.id = UUID().uuidString }
            result.added.append(new)
        }
        return result
    }
}
