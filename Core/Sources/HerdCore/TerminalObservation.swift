import Foundation

/// A read-only Herdr observer uses pipes, never a second interactive terminal.
@MainActor public final class TerminalObservation {
    private final class Run: @unchecked Sendable {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
    }
    private var run: Run?
    private var command: ((UInt16, UInt16) -> String)?
    private var resizeTask: Task<Void, Never>?
    private var columns: UInt16 = 80
    private var rows: UInt16 = 24
    public var output: ((Data) -> Void)?
    public var ended: ((String) -> Void)?
    public init() {}
    public var isRunning: Bool { run != nil }
    public func start(_ command: @escaping (UInt16, UInt16) -> String) {
        stop(); self.command = command
        let context = Run()
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = [environment["PATH"] ?? "", "/opt/homebrew/bin", "/usr/local/bin", NSHomeDirectory() + "/.local/bin", "/usr/bin", "/bin"].joined(separator: ":")
        context.process.executableURL = URL(fileURLWithPath: "/bin/sh")
        context.process.arguments = ["-c", command(columns, rows)]
        context.process.environment = environment
        context.process.standardInput = FileHandle.nullDevice
        context.process.standardOutput = context.output
        context.process.standardError = context.error
        do { try context.process.run() } catch { self.command = nil; ended?(error.localizedDescription); return }
        run = context
        // Drain diagnostics separately so a full stderr pipe cannot stop the stream.
        DispatchQueue.global(qos: .utility).async {
            while let data = try? context.error.fileHandleForReading.read(upToCount: 8192), !data.isEmpty {}
            try? context.error.fileHandleForReading.close()
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var decoder = TerminalFrameDecoder()
            var reason = "Terminal observation ended"
            do {
                while let data = try context.output.fileHandleForReading.read(upToCount: 65536), !data.isEmpty {
                    let frames = try decoder.append(data)
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.run === context else { return }
                        for frame in frames { self.output?(frame) }
                    }
                }
                reason = decoder.closedReason ?? reason
            } catch { reason = error.localizedDescription }
            try? context.output.fileHandleForReading.close()
            let finalReason = reason
            DispatchQueue.main.async { [weak self] in
                guard let self, self.run === context else { return }
                self.stop(); self.ended?(finalReason)
            }
        }
    }
    public func resize(_ columns: UInt16, _ rows: UInt16) {
        guard columns > 0, rows > 0, (self.columns != columns || self.rows != rows) else { return }
        self.columns = columns; self.rows = rows
        guard let command else { return }
        resizeTask?.cancel()
        resizeTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            self?.start(command)
        }
    }
    public func stop() {
        resizeTask?.cancel(); resizeTask = nil; command = nil
        let old = run; run = nil
        if let old, old.process.isRunning { old.process.terminate() }
    }
    deinit { if let run, run.process.isRunning { run.process.terminate() } }
}
