import XCTest
import Darwin
import HerdCore

/// A real Unix socket exercises framing, snapshot validation and event recovery.
final class TestRPCServer {
    let path = "/tmp/hxt-" + UUID().uuidString.prefix(10) + ".sock"
    private final class Listener: @unchecked Sendable {
        let fd: Int32
        private let lock = NSLock()
        private var closed = false
        init(_ fd: Int32) { self.fd = fd }
        func stop() { lock.lock(); defer { lock.unlock() }; if !closed { shutdown(fd, SHUT_RDWR) } }
        func finish() { lock.lock(); defer { lock.unlock() }; if !closed { closed = true; close(fd) } }
    }
    private let listener: Listener
    private let activity: NSObjectProtocol
    convenience init(requests: Int, handler: @escaping @Sendable (JSON) -> [JSON]) throws {
        try self.init(requests: requests, rawHandler: { request in
            handler(request).compactMap { try? JSONEncoder().encode($0) }.reduce(into: Data()) { $0 += $1 + Data([10]) }
        })
    }
    init(requests: Int, concurrent: Bool = false, fragmentSize: Int = 17, rawHandler: @escaping @Sendable (JSON) -> Data) throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var address = sockaddr_un(); address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        let bound = withUnsafePointer(to: &address) { p in p.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        guard bound == 0, listen(fd, 8) == 0 else { close(fd); throw Failure("Test socket failed") }
        let listener = Listener(fd); self.listener = listener
        // A background xctest process can coalesce a 20ms fixture sleep to
        // 150ms. Measure foreground interaction, not App Nap's timer policy.
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "Measure isolated foreground RPC latency")
        Thread.detachNewThread {
            Thread.current.qualityOfService = .userInitiated
            // The accept loop owns close. Closing from deinit can let this loop
            // accept on a reused descriptor belonging to the next fixture.
            defer { listener.finish() }
            for _ in 0..<requests {
                let peer = accept(fd, nil, nil); guard peer >= 0 else { break }
                let respond: @Sendable () -> Void = {
                    Thread.current.qualityOfService = .userInitiated
                    var noPipe: Int32 = 1
                    guard setsockopt(peer, SOL_SOCKET, SO_NOSIGPIPE, &noPipe, 4) == 0 else {
                        XCTFail("Cannot protect fixture socket from SIGPIPE: \(errno)"); close(peer); return
                    }
                    var data = Data(), bytes = [UInt8](repeating: 0, count: 4096)
                    while !data.contains(10) { let count = read(peer, &bytes, bytes.count); if count <= 0 { break }; data.append(contentsOf: bytes.prefix(count)) }
                    if let end = data.firstIndex(of: 10), let request = try? JSONDecoder().decode(JSON.self, from: data[..<end]) {
                        rawHandler(request).withUnsafeBytes { raw in
                            var offset = 0
                            while offset < raw.count { let count = write(peer, raw.baseAddress!.advanced(by: offset), min(max(1, fragmentSize), raw.count - offset)); if count <= 0 { break }; offset += count }
                        }
                    }
                    close(peer)
                }
                if concurrent { Thread.detachNewThread(respond) } else { respond() }
            }
        }
    }
    deinit { listener.stop(); ProcessInfo.processInfo.endActivity(activity); try? FileManager.default.removeItem(atPath: path) }
}

