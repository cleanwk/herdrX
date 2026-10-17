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
        var pendingOffset = 0
        // One reusable read buffer per run: high-throughput output otherwise
        // allocates 64 KiB for every readable event.
        var readBuffer = [UInt8](repeating: 0, count: 65536)
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
    private var resizeTotal = 0
    var resizeCount: Int { state.lock(); defer { state.unlock() }; return resizeTotal }
    var output: (@Sendable (Data) -> Void)?
    var exited: ((Int32) -> Void)?
    var inputRejected: (() -> Void)?
    func start(_ command: String, environment supplied: [String: String]? = nil) {
        stop()
        var environment = supplied ?? ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"; environment["COLORTERM"] = "truecolor"
        environment["PATH"] = [environment["PATH"] ?? "", "/opt/homebrew/bin", "/usr/local/bin", NSHomeDirectory() + "/.local/bin", "/usr/bin", "/bin"].joined(separator: ":")
        var argv = ["/bin/zsh", "-l", "-c", command].map { strdup($0) } + [nil]
        var env = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; env.forEach { free($0) } }
        var fd: Int32 = -1
        let pid = herd_pty(&fd, "/bin/zsh", &argv, &env)
        guard pid > 0 else { exited?(127 << 8); return }
        let context = Run(fd: fd, pid: pid)
        state.lock(); generation += 1; let epoch = generation; run = context; state.unlock()
        let output = self.output
        context.queue.async { [weak self] in
            let reader = DispatchSource.makeReadSource(fileDescriptor: fd, queue: context.queue)
            reader.setCancelHandler { close(fd) }
            reader.setEventHandler {
                guard context.active else { return }
                let count = read(fd, &context.readBuffer, context.readBuffer.count)
                if count > 0 {
                    guard let self else { return }
                    self.state.lock(); defer { self.state.unlock() }
                    guard self.generation == epoch, self.run === context else { return }
                    output?(Data(context.readBuffer.prefix(count)))
                }
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
        context.queue.async { [weak self] in
            guard context.active else { return }
            let queued = context.pending.count - context.pendingOffset
            guard queued + data.count <= 16 * 1024 * 1024 else { DispatchQueue.main.async { rejected?() }; return }
            context.pending.append(data)
            if context.writer == nil {
                let writer = DispatchSource.makeWriteSource(fileDescriptor: context.fd, queue: context.queue)
                writer.setEventHandler {
                    guard context.active, let self else { return }
                    self.state.lock(); defer { self.state.unlock() }
                    guard self.run === context else { return }
                    guard context.pendingOffset < context.pending.count else {
                        context.pending.removeAll(keepingCapacity: true); context.pendingOffset = 0
                        context.writer?.cancel(); context.writer = nil; return
                    }
                    let n = context.pending.withUnsafeBytes { raw in
                        Darwin.write(context.fd, raw.baseAddress!.advanced(by: context.pendingOffset), raw.count - context.pendingOffset)
                    }
                    if n > 0 {
                        context.pendingOffset += n
                        if context.pendingOffset >= context.pending.count {
                            context.pending.removeAll(keepingCapacity: true); context.pendingOffset = 0
                        } else if context.pendingOffset > 64 * 1024 {
                            // Compact occasionally instead of moving the remaining
                            // bytes after every partial write.
                            context.pending.removeFirst(context.pendingOffset); context.pendingOffset = 0
                        }
                    }
                    else if n < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { context.pending.removeAll(); context.pendingOffset = 0; context.writer?.cancel(); context.writer = nil; return }
                    if context.pendingOffset >= context.pending.count { context.writer?.cancel(); context.writer = nil }
                }
                context.writer = writer; writer.activate()
            }
        }
    }
    func resize(_ columns: UInt16, _ rows: UInt16) {
        state.lock(); let context = run; if context != nil { resizeTotal += 1 }; state.unlock()
        context?.queue.async {
            guard let context, context.active else { return }
            var size = winsize(ws_row: rows, ws_col: columns, ws_xpixel: 0, ws_ypixel: 0)
            _ = ioctl(context.fd, TIOCSWINSZ, &size)
        }
    }
    enum Activity { case idle, running, unknown }
    func foregroundActivity() -> Activity {
        state.lock(); let context = run; state.unlock()
        guard let context else { return .unknown }
        context.lock.lock(); let reaped = context.reaped; context.lock.unlock()
        if reaped { return .idle }
        var foreground: Int32 = 0
        context.queue.sync { if context.active { _ = ioctl(context.fd, TIOCGPGRP, &foreground) } }
        guard foreground > 0 else { return .unknown }
        if foreground != context.pid { return .running }
        return herd_is_shell(context.pid) != 0 ? .idle : .unknown
    }
    func cwd() -> String? {
        state.lock(); let context = run; state.unlock()
        guard let context else { return nil }
        // Resolve foreground process rather than a cached shell launch path.
        var foreground: Int32 = 0
        context.queue.sync { if context.active { _ = ioctl(context.fd, TIOCGPGRP, &foreground) } }
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
