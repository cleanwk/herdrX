import Foundation
import Darwin
import PTY

/// A run owns its descriptors. Teardown and writes serialize on its IO queue.
final class ByteProcess: @unchecked Sendable {
    private final class Run: @unchecked Sendable {
        let queue = DispatchQueue(label: "herd.pty")
        let fd: Int32
        let pid: pid_t
        var reader: DispatchSourceRead?
        var writer: DispatchSourceWrite?
        var active = true
        var pending = Data()
        let lock = NSLock()
        var reaped = false
        init(fd: Int32, pid: pid_t) { self.fd = fd; self.pid = pid }
        func stop() {
            queue.async {
                self.active = false
                self.writer?.cancel(); self.writer = nil
                self.reader?.cancel(); self.reader = nil
            }
            lock.lock(); if !reaped { kill(-pid, SIGHUP); kill(pid, SIGHUP) }; lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                self.lock.lock(); defer { self.lock.unlock() }
                if !self.reaped { kill(-self.pid, SIGKILL); kill(self.pid, SIGKILL) }
            }
        }
    }
    private let state = NSLock()
    private var run: Run?
    private var generation = 0
    var output: (@Sendable (Data) -> Void)?
    var exited: ((Int32) -> Void)?
    var inputRejected: (() -> Void)?
    func start(_ command: String) {
        stop()
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"; environment["COLORTERM"] = "truecolor"
        environment["PATH"] = [environment["PATH"] ?? "", "/opt/homebrew/bin", "/usr/local/bin", NSHomeDirectory() + "/.local/bin", "/usr/bin", "/bin"].joined(separator: ":")
        var argv = ["/bin/zsh", "-l", "-c", command].map { strdup($0) } + [nil]
        var env = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; env.forEach { free($0) } }
        var fd: Int32 = -1
        let pid = herd_pty(&fd, "/bin/zsh", &argv, &env)
        guard pid > 0 else { exited?(127); return }
        let context = Run(fd: fd, pid: pid)
        state.lock(); generation += 1; let epoch = generation; run = context; state.unlock()
        let output = self.output
        context.queue.async {
            let reader = DispatchSource.makeReadSource(fileDescriptor: fd, queue: context.queue)
            reader.setCancelHandler { close(fd) }
            reader.setEventHandler {
                guard context.active else { return }
                var bytes = [UInt8](repeating: 0, count: 65536)
                let count = read(fd, &bytes, bytes.count)
                if count > 0 { output?(Data(bytes.prefix(count))) }
                else if count == 0 || (count < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) { context.active = false; context.writer?.cancel(); context.writer = nil; context.reader?.cancel(); context.reader = nil }
            }
            context.reader = reader; reader.activate()
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var status: Int32 = 0
            while waitpid(pid, &status, 0) < 0 && errno == EINTR {}
            context.lock.lock(); context.reaped = true; context.lock.unlock()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.state.lock(); let valid = self.generation == epoch; self.state.unlock()
                if valid { self.exited?(status) }
            }
        }
    }
    func write(_ data: Data) {
        state.lock(); let context = run; state.unlock()
        guard let context else { return }
        let rejected = inputRejected
        context.queue.async {
            guard context.active else { return }
            guard context.pending.count + data.count <= 16 * 1024 * 1024 else { DispatchQueue.main.async { rejected?() }; return }
            context.pending.append(data)
            if context.writer == nil {
                let writer = DispatchSource.makeWriteSource(fileDescriptor: context.fd, queue: context.queue)
                writer.setEventHandler {
                    guard context.active else { return }
                    let n = context.pending.withUnsafeBytes { Darwin.write(context.fd, $0.baseAddress, $0.count) }
                    if n > 0 { context.pending.removeFirst(n) }
                    else if n < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { context.pending.removeAll(); context.writer?.cancel(); context.writer = nil; return }
                    if context.pending.isEmpty { context.writer?.cancel(); context.writer = nil }
                }
                context.writer = writer; writer.activate()
            }
        }
    }
    func resize(_ columns: UInt16, _ rows: UInt16) {
        state.lock(); let context = run; state.unlock()
        context?.queue.async {
            guard let context, context.active else { return }
            var size = winsize(ws_row: rows, ws_col: columns, ws_xpixel: 0, ws_ypixel: 0)
            ioctl(context.fd, TIOCSWINSZ, &size)
        }
    }
    func cwd() -> String? {
        state.lock(); let context = run; state.unlock()
        guard let context else { return nil }
        // Resolve foreground process rather than a cached shell launch path.
        var foreground: Int32 = 0
        context.queue.sync { if context.active { ioctl(context.fd, TIOCGPGRP, &foreground) } }
        var path = [CChar](repeating: 0, count: 4096)
        guard herd_cwd(foreground > 0 ? foreground : context.pid, &path, Int32(path.count)) != 0 else { return nil }
        return String(cString: path)
    }
    func stop() {
        state.lock(); generation += 1; let old = run; run = nil; state.unlock()
        old?.stop()
    }
    deinit { stop() }
}
