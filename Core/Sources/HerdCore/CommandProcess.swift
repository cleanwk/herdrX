import Foundation

/// Runs bounded helper commands for connection discovery and Git metadata.
public final class CommandProcess: @unchecked Sendable {
    private let lock = NSLock()
    private let process = Process()
    private var cancelled = false
    func cancel() { lock.lock(); defer { lock.unlock() }; cancelled = true; if process.isRunning { process.terminate() } }
    public static func run(_ executable: String, _ arguments: [String], input: Data) async throws -> Data {
        let runner = CommandProcess()
        return try await withTaskCancellationHandler {
            try await Task.detached { try runner.execute(executable, arguments, input: input) }.value
        } onCancel: { runner.cancel() }
    }
    private func execute(_ executable: String, _ arguments: [String], input: Data) throws -> Data {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("herdrx-command-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]); defer { try? FileManager.default.removeItem(at: dir) }
        let inURL = dir.appendingPathComponent("in"), outURL = dir.appendingPathComponent("out"), errURL = dir.appendingPathComponent("err")
        try input.write(to: inURL); FileManager.default.createFile(atPath: outURL.path, contents: nil); FileManager.default.createFile(atPath: errURL.path, contents: nil)
        let stdin = try FileHandle(forReadingFrom: inURL), stdout = try FileHandle(forWritingTo: outURL), stderr = try FileHandle(forWritingTo: errURL)
        defer { try? stdin.close(); try? stdout.close(); try? stderr.close() }
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments; process.standardInput = stdin; process.standardOutput = stdout; process.standardError = stderr
        lock.lock()
        if cancelled { lock.unlock(); throw CancellationError() }
        do { try process.run() } catch { lock.unlock(); throw error }; lock.unlock()
        process.waitUntilExit()
        lock.lock(); let wasCancelled = cancelled; lock.unlock()
        if wasCancelled { throw CancellationError() }
        guard process.terminationStatus == 0 else { throw Failure(String(decoding: try Data(contentsOf: errURL), as: UTF8.self)) }
        return try Data(contentsOf: outURL)
    }
}
