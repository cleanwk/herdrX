import Foundation
import Darwin
import PTY

/// Bounded helpers. Each invocation owns a process group; cancellation also
/// stops shell children, independently of newer connections.
public final class CommandProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    private var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    public static func run(_ executable: String, _ arguments: [String], input: Data, timeout: TimeInterval = 30, outputLimit: Int = 4 * 1024 * 1024, environment: [String: String]? = nil) async throws -> Data {
        let runner = CommandProcess()
        return try await withTaskCancellationHandler {
            try await Task.detached { try runner.execute(executable, arguments, input: input, timeout: timeout, outputLimit: outputLimit, environment: environment) }.value
        } onCancel: { runner.cancel() }
    }
    private func execute(_ executable: String, _ arguments: [String], input: Data, timeout: TimeInterval, outputLimit: Int, environment: [String: String]?) throws -> Data {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("herdrx-command-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]); defer { try? FileManager.default.removeItem(at: dir) }
        let inURL = dir.appendingPathComponent("in"), outURL = dir.appendingPathComponent("out"), errURL = dir.appendingPathComponent("err")
        try input.write(to: inURL); FileManager.default.createFile(atPath: outURL.path, contents: nil); FileManager.default.createFile(atPath: errURL.path, contents: nil)
        let stdin = try FileHandle(forReadingFrom: inURL), stdout = try FileHandle(forWritingTo: outURL), stderr = try FileHandle(forWritingTo: errURL)
        defer { try? stdin.close(); try? stdout.close(); try? stderr.close() }
        var env = environment ?? ProcessInfo.processInfo.environment
        env["PATH"] = NSHomeDirectory() + "/.local/bin:/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
        var argv = ([executable] + arguments).map { strdup($0) } + [nil]
        var envp = env.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }
        if isCancelled { throw CancellationError() }
        let pid = herd_command(executable, &argv, &envp, stdin.fileDescriptor, stdout.fileDescriptor, stderr.fileDescriptor)
        guard pid > 0 else { throw Failure("Could not launch " + executable) }
        var status: Int32 = 0, reaped = false
        defer {
            kill(-pid, SIGKILL)
            if !reaped { while waitpid(pid, &status, 0) < 0 && errno == EINTR {} }
        }
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while true {
            if isCancelled { throw CancellationError() }
            var out = stat(), err = stat()
            if fstat(stdout.fileDescriptor, &out) == 0, fstat(stderr.fileDescriptor, &err) == 0,
               out.st_size + err.st_size > outputLimit { throw Failure("Command output exceeded its limit.") }
            let result = waitpid(pid, &status, WNOHANG)
            if result == pid { reaped = true; break }
            if result < 0, errno != EINTR { throw Failure("Could not wait for command.") }
            if ProcessInfo.processInfo.systemUptime >= deadline { throw Failure("Command timed out.") }
            Thread.sleep(forTimeInterval: 0.02)
        }
        if isCancelled { throw CancellationError() }
        guard status == 0 else {
            let detail = String(decoding: try Data(contentsOf: errURL).prefix(4000), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw Failure(detail.isEmpty ? "Command exited with status \(status)." : detail)
        }
        let output = try Data(contentsOf: outURL)
        guard output.count <= outputLimit else { throw Failure("Command output exceeded its limit.") }
        return output
    }
}
