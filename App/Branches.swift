import Foundation
import HerdCore

struct BranchState {
    enum Phase { case loading, branch, directory, failed, stale }
    let phase: Phase
    let value: String
    let detail: String
    var text: String {
        switch phase {
        case .branch, .stale: value
        case .loading, .directory, .failed: L("Directory")
        }
    }
    // Branch lookup is optional metadata, not a directory or session health check.
    var symbol: String { phase == .branch || phase == .stale ? "arrow.triangle.branch" : "folder" }
}
extension Desk {
    func refreshBranches(_ device: Device, snapshot: Session) {
        for space in snapshot.spaces {
            let key = device.id + "|" + space.id
            guard let path = spacePath(device: device.id, space: space.id) else { branchStates[key] = BranchState(phase: .failed, value: "", detail: L("Directory is unavailable.")); continue }
            let context = DisplayTitle.detail([path, device.endpoint.kind, device.endpoint.target, device.endpoint.sshConfig, device.endpoint.port.map(String.init)])
            if branchContexts[key] != context {
                branchContexts[key] = context; branchRequests[key] = nil; branchUpdated[key] = nil; branches[key] = nil
                branchStates[key] = BranchState(phase: .loading, value: "", detail: path)
            }
            if let branch = space.tokens["branch"]?.string {
                branches[key] = branch; branchStates[key] = BranchState(phase: branch.isEmpty ? .directory : .branch, value: branch.isEmpty ? URL(fileURLWithPath: path).lastPathComponent : branch, detail: path); continue
            }
            guard ["local", "ssh"].contains(device.endpoint.kind) else { branchStates[key] = BranchState(phase: .directory, value: URL(fileURLWithPath: path).lastPathComponent, detail: path); continue }
            guard branchRequests[key] == nil, branchUpdated[key].map({ Date().timeIntervalSince($0) > 30 }) ?? true else { continue }
            let token = UUID(); branchRequests[key] = token
            Task {
                defer { if branchRequests[key] == token { branchRequests[key] = nil; branchUpdated[key] = Date() } }
                do {
                    let command = "cd " + quote(path) + " && export LC_ALL=C; " + "test -d " + quote(path) + " || exit 1; " + "out=$(git -C " + quote(path) + " rev-parse --is-inside-work-tree 2>&1); result=$?; " + "if [ $result -eq 0 ]; then git -C " + quote(path) + " symbolic-ref --quiet --short HEAD || git -C " + quote(path) + " rev-parse --short HEAD; " + "else case \"$out\" in *'not a git repository'*) printf '\\n';; *) printf '%s' \"$out\" >&2; exit 1;; esac; fi"
                    let data: Data
                    if device.endpoint.kind == "ssh", let host = device.endpoint.target {
                        data = try await CommandProcess.run("/usr/bin/ssh", (device.endpoint.sshConfig.map { ["-F", $0] } ?? []) + ["-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10"] + (device.endpoint.port.map { ["-p", String($0)] } ?? []) + [host, command], input: Data())
                    } else { data = try await CommandProcess.run("/bin/sh", ["-c", command], input: Data()) }
                    guard branchRequests[key] == token, branchContexts[key] == context, devices.contains(device), spacePath(device: device.id, space: space.id) == path else { return }
                    let value = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    branches[key] = value; branchStates[key] = BranchState(phase: value.isEmpty ? .directory : .branch, value: value.isEmpty ? URL(fileURLWithPath: path).lastPathComponent : value, detail: path); reindex()
                } catch {
                    guard branchRequests[key] == token, branchContexts[key] == context else { return }
                    let previous = branches[key] ?? ""
                    branchStates[key] = BranchState(phase: previous.isEmpty ? .failed : .stale, value: previous, detail: path + "\n" + L("Git branch information could not be refreshed.") + "\n" + error.localizedDescription)
                }
            }
        }
    }
}
