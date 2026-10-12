import Foundation

public enum TerminalInputRecovery {
    // Local emulator control bytes, never sent as input to the server PTY.
    // Leave screen, scrollback and the shell's bracketed-paste mode intact.
    public static let bytes = Data(("\u{1b}[<99u\u{1b}[=0u\u{1b}[>4;0m"
        + [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1015, 1016].map { "\u{1b}[?\($0)l" }.joined()).utf8)
    public static func isIdleShell(_ info: JSON, pane: String) -> Bool {
        guard info["pane_id"].string == pane, let shell = info["shell_pid"].int, shell > 0,
              info["foreground_process_group_id"].int == shell else { return false }
        let processes = info["foreground_processes"].array
        return !processes.isEmpty && processes.allSatisfy { process in
            let name = (process["name"].string ?? "").split(separator: "/").last.map(String.init) ?? ""
            return process["pid"].int == shell && ["sh", "bash", "zsh", "fish", "dash", "ksh", "tcsh", "csh"].contains(name)
        }
    }
}
