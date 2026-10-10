import Foundation
import HerdCore

extension Desk {
    func importHerdrMachines() {
        Task {
            do {
                let bytes = try await FileProcess.run("/bin/zsh", ["-lc", "exec herdr machine list --json"], input: Data())
                let value = try JSONDecoder().decode(JSON.self, from: bytes)
                guard case .array(let rows) = value else { throw Failure("Invalid Herdr machine list.") }
                var imported: [Device] = []
                for row in rows where row["enabled"] != .bool(false) {
                    guard let id = row["id"].string, let label = row["label"].string, let host = row["target"].string,
                          !host.isEmpty, !host.hasPrefix("-"), !host.contains(where: \.isWhitespace), let name = row["session"].string else { throw Failure("A saved machine is missing its ID, target or named session.") }
                    if devices.contains(where: { $0.id == "herdr-machine." + id }) { continue }
                    let command = "export PATH=\"$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH\"; exec herdr session list --json"
                    let data = try await FileProcess.run("/usr/bin/ssh", ["-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host, "/bin/sh -lc " + quote(command)], input: Data())
                    let sessions = try JSONDecoder().decode(JSON.self, from: data)
                    guard let session = sessions["sessions"].array.first(where: { $0["name"].string == name }), let path = session["socket_path"].string, path.hasPrefix("/") else { throw Failure("Cannot resolve named session “\(name)” on \(label). No connections were imported.") }
                    imported.append(Device(id: "herdr-machine." + id, displayName: label, endpoint: .init(kind: "ssh", target: host, socketPath: path)))
                }
                for device in imported where !devices.contains(where: { $0.endpoint == device.endpoint }) { add(device) }
                if imported.isEmpty { message = "No new enabled Herdr machines to import." }
            } catch { message = "Import failed; existing devices are unchanged. " + error.localizedDescription }
        }
    }
}
