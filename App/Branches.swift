import Foundation
import HerdCore

extension Desk {
    func refreshBranches(_ device: Device, snapshot: Session) {
        for space in snapshot.spaces {
            let key = device.id + "|" + space.id
            if let branch = space.tokens["branch"]?.string { branches[key] = branch; continue }
            guard let path = space.cwd ?? snapshot.panes.first(where: { $0.workspace == space.id })?.cwd,
                  ["local", "ssh"].contains(device.endpoint.kind), branchRequests[key] == nil,
                  branchUpdated[key].map({ Date().timeIntervalSince($0) > 30 }) ?? true else { continue }
            let token = UUID(); branchRequests[key] = token
            Task {
                defer { if branchRequests[key] == token { branchRequests[key] = nil; branchUpdated[key] = Date() } }
                do {
                    let command = "git -C " + quote(path) + " symbolic-ref --quiet --short HEAD 2>/dev/null || :"
                    let data: Data
                    if device.endpoint.kind == "ssh", let host = device.endpoint.target {
                        data = try await FileProcess.run("/usr/bin/ssh", (device.endpoint.sshConfig.map { ["-F", $0] } ?? []) + ["-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10"] + (device.endpoint.port.map { ["-p", String($0)] } ?? []) + [host, command], input: Data())
                    } else { data = try await FileProcess.run("/bin/sh", ["-c", command], input: Data()) }
                    guard branchRequests[key] == token, devices.contains(device), sessions[device.id]?.spaces.contains(where: { $0.id == space.id }) == true else { return }
                    let current = sessions[device.id]
                    guard (current?.spaces.first(where: { $0.id == space.id })?.cwd ?? current?.panes.first(where: { $0.workspace == space.id })?.cwd) == path else { return }
                    branches[key] = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines); reindex()
                } catch { /* A failed query keeps the reserved second line, never claims a branchless directory. */ }
            }
        }
    }
}
