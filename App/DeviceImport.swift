import Foundation
import HerdCore

extension Desk {
    private func beginDiscovery(_ status: String) -> Bool {
        guard !discoveringDevices else { return false }
        discoveringDevices = true; cancellingDiscovery = false; discoveryStatus = L(status); discoveryError = nil
        return true
    }
    private func finishDiscovery(_ count: Int) {
        discoveryStatus = count == 0 ? L("No new connections found.") : count == 1 ? L("Added 1 connection.") : LF("Added %d connections.", count)
    }
    func cancelDeviceDiscovery() {
        guard discoveringDevices, !cancellingDiscovery else { return }
        cancellingDiscovery = true; discoveryStatus = L("Cancelling…"); discoveryTask?.cancel()
    }
    func discoverSessions() {
        guard beginDiscovery("Finding local sessions…") else { return }
        discoveryTask = Task {
            defer { discoveringDevices = false; cancellingDiscovery = false; discoveryTask = nil }
            do {
                let bytes = try await CommandProcess.run("/bin/zsh", ["-lc", "exec herdr session list --json"], input: Data())
                let value = try JSONDecoder().decode(JSON.self, from: bytes)
                guard case .array(let rows) = value["sessions"] else { throw Failure(L("Herdr returned an invalid session list.")) }
                let discovered = try rows.map { row -> Device in
                    guard let name = row["name"].string, let path = row["socket_path"].string, path.hasPrefix("/") else { throw Failure(L("A discovered session is missing its name or absolute socket path.")) }
                    return Device(displayName: name, endpoint: .init(kind: "local", socketPath: path))
                }
                try Task.checkCancellation()
                var count = 0
                for device in discovered where !devices.contains(where: { $0.endpoint == device.endpoint }) { add(device); count += 1 }
                finishDiscovery(count)
            } catch is CancellationError { discoveryStatus = L("Cancelled.") }
            catch { discoveryStatus = nil; discoveryError = LF("Could not find sessions: %@", error.localizedDescription) }
        }
    }
    func importHerdrMachines() {
        guard beginDiscovery("Importing Herdr machines…") else { return }
        discoveryTask = Task {
            defer { discoveringDevices = false; cancellingDiscovery = false; discoveryTask = nil }
            do {
                let bytes = try await CommandProcess.run("/bin/zsh", ["-lc", "exec herdr machine list --json"], input: Data())
                let value = try JSONDecoder().decode(JSON.self, from: bytes)
                guard case .array(let rows) = value else { throw Failure(L("Invalid Herdr machine list.")) }
                var imported: [Device] = []
                for row in rows where row["enabled"] != .bool(false) {
                    try Task.checkCancellation()
                    guard let id = row["id"].string, let label = row["label"].string, let host = row["target"].string,
                          !host.isEmpty, !host.hasPrefix("-"), !host.contains(where: \.isWhitespace), let name = row["session"].string else { throw Failure(L("A saved machine is missing its ID, target or named session.")) }
                    if devices.contains(where: { $0.id == "herdr-machine." + id }) { continue }
                    let command = "export PATH=\"$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH\"; exec herdr session list --json"
                    let data = try await CommandProcess.run("/usr/bin/ssh", ["-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host, "/bin/sh -lc " + quote(command)], input: Data())
                    let sessions = try JSONDecoder().decode(JSON.self, from: data)
                    guard let session = sessions["sessions"].array.first(where: { $0["name"].string == name }), let path = session["socket_path"].string, path.hasPrefix("/") else { throw Failure(LF("Cannot find session “%@” on %@.", name, label)) }
                    imported.append(Device(id: "herdr-machine." + id, displayName: label, endpoint: .init(kind: "ssh", target: host, socketPath: path)))
                }
                try Task.checkCancellation()
                var count = 0
                for device in imported where !devices.contains(where: { $0.id == device.id || $0.endpoint == device.endpoint }) { add(device); count += 1 }
                finishDiscovery(count)
            } catch is CancellationError { discoveryStatus = L("Cancelled.") }
            catch { discoveryStatus = nil; discoveryError = LF("Could not import connections: %@", error.localizedDescription) }
        }
    }
}
