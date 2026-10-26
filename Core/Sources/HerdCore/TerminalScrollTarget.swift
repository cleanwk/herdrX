import Foundation

/// Read-only preflight for one wheel batch. The two independent reads overlap;
/// no process state is cached across batches or used to infer Agent status.
public enum TerminalScrollTarget: Equatable, Sendable {
    case foreground
    case history(offset: Int, maximum: Int)

    public static func read(_ client: RPC, pane: String, terminal: String) async throws -> Self {
        let position = Task { try await client.call("pane.get", ["pane_id": .string(pane)], timeout: 3)["pane"] }
        defer { position.cancel() }
        let info = try await client.call("pane.process_info", ["pane_id": .string(pane)], timeout: 3)["process_info"]
        try Task.checkCancellation()
        guard info["pane_id"].string == pane, (info["shell_pid"].int ?? 0) > 0,
              (info["foreground_process_group_id"].int ?? 0) > 0, !info["foreground_processes"].array.isEmpty else {
            throw Failure("Missing foreground process information")
        }
        // A foreground TUI does not wait for history metadata. Cancellation of
        // this speculative read cannot send terminal input or mutate a session.
        guard TerminalInputRecovery.isIdleShell(info, pane: pane) else { return .foreground }
        let value = try await position.value
        try Task.checkCancellation()
        guard value["pane_id"].string == pane, value["terminal_id"].string == terminal,
              let offset = value["scroll"]["offset_from_bottom"].int,
              let maximum = value["scroll"]["max_offset_from_bottom"].int else {
            throw Failure("Missing terminal scroll information")
        }
        return .history(offset: offset, maximum: maximum)
    }
}
