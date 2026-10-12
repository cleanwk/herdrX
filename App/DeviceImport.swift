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
    func importHerdrMachines() { syncHerdrMachines(manual: true) }
    func syncHerdrMachines(manual: Bool = false) {
        guard machineSyncTask == nil, manual || followHerdrMachines else { return }
        if manual, !beginDiscovery("Importing Herdr machines…") { return }
        machineSyncTask = Task {
            defer {
                machineSyncTask = nil
                if manual { discoveringDevices = false; cancellingDiscovery = false; discoveryTask = nil }
            }
            do {
                let bytes = try await CommandProcess.run("/bin/zsh", ["-lc", "exec herdr machine list --json"], input: Data(), timeout: 15)
                let catalog = try HerdrMachines(data: bytes)
                try Task.checkCancellation()
                let changes = catalog.changes(to: devices, removeMissing: followHerdrMachines)
                for id in changes.removed { remove(id) }
                for device in changes.updated { update(device) }
                for device in changes.added { add(device) }
                machineSyncError = catalog.warnings.isEmpty ? nil : LF("Invalid machine entries kept unchanged: %@", catalog.warnings.joined(separator: ", "))
                if manual { finishDiscovery(changes.added.count); discoveryError = machineSyncError }
            } catch is CancellationError {
                if manual { discoveryStatus = L("Cancelled.") }
            } catch {
                // No mutations until the entire local read and decode succeed.
                machineSyncError = LF("Could not sync Herdr machines. Existing devices were kept: %@", error.localizedDescription)
                if manual { discoveryStatus = nil; discoveryError = machineSyncError }
            }
        }
        if manual { discoveryTask = machineSyncTask }
    }
    func setFollowHerdrMachines(_ enabled: Bool) {
        followHerdrMachines = enabled
        UserDefaults.standard.set(enabled, forKey: "followHerdrMachines")
        if enabled { syncHerdrMachines() }
        else { machineSyncTask?.cancel(); machineSyncError = nil }
    }
    func startHerdrIntegration() {
        applicationActivated()
        integrationTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                self?.applicationActivated()
            }
        }
    }
    func applicationActivated() {
        syncHerdrMachines()
        reloadHerdrConfig()
        refreshPluginCatalogs()
    }
}
