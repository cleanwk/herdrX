import Foundation

/// A user-requested native Herdr server launch, not a client-owned service manager.
/// Releasing this handle or quitting the GUI leaves Herdr and its sessions running.
@MainActor
public final class LocalHerdrLaunch {
    public struct MissingExecutable: LocalizedError {
        public var errorDescription: String? { "Herdr was not found in ~/.local/bin, Homebrew or PATH." }
    }
    public let process = Process()
    private let logURL: URL
    public init(target: LocalHerdrTarget, searchPaths: [String]? = nil) throws {
        let home = NSHomeDirectory()
        let paths = searchPaths ?? ([home + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"] + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init))
        guard let executable = paths.map({ $0 + "/herdr" }).first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw MissingExecutable()
        }
        logURL = FileManager.default.temporaryDirectory.appendingPathComponent("herdrx-start-" + UUID().uuidString + ".log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let log = try FileHandle(forWritingTo: logURL); defer { try? log.close() }
        var environment = ProcessInfo.processInfo.environment
        // The captured canonical endpoint wins over inherited terminal overrides.
        for key in ["HERDR_SOCKET_PATH", "HERDR_CONFIG_PATH", "HERDR_SESSION", "HERDR_SESSION_NAME"] { environment.removeValue(forKey: key) }
        environment["XDG_CONFIG_HOME"] = home + "/.config"
        process.environment = environment
        process.currentDirectoryURL = URL(fileURLWithPath: home)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = target.arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = log; process.standardError = log
        do { try process.run() }
        catch { try? FileManager.default.removeItem(at: logURL); throw error }
    }
    public var diagnostic: String {
        guard let file = try? FileHandle(forReadingFrom: logURL) else { return "" }
        defer { try? file.close() }
        return String(decoding: (try? file.read(upToCount: 8192)) ?? Data(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    deinit { try? FileManager.default.removeItem(at: logURL) }
}
