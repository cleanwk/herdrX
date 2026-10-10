import Foundation
import Darwin

/// Short-lived control connections. Terminal bytes never enter this channel.
public struct RPC: Sendable {
    public let path: String
    public init(path: String) { self.path = path }
    public func call(_ method: String, _ params: [String: JSON] = [:], timeout: Int = 15) async throws -> JSON {
        let path = path
        return try await Task.detached {
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { throw Failure("Cannot open socket") }
            defer { close(fd) }
            _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
            var noPipe: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noPipe, 4)
            var timeout = timeval(tv_sec: min(300, max(1, timeout)), tv_usec: 0)
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            var address = sockaddr_un(); address.sun_family = sa_family_t(AF_UNIX)
            let bytes = Array(path.utf8)
            guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw Failure("Socket path is too long") }
            withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
            let result = withUnsafePointer(to: &address) { p in
                p.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
            }
            guard result == 0 else { throw Failure("Cannot connect to \(path): \(String(cString: strerror(errno)))") }
            let id = UUID().uuidString
            let request = try JSONEncoder().encode(JSON.object(["id": .string(id), "method": .string(method), "params": .object(params)])) + Data([10])
            try request.withUnsafeBytes { raw in
                var offset = 0
                while offset < raw.count {
                    let n = write(fd, raw.baseAddress!.advanced(by: offset), raw.count - offset)
                    if n < 0 && errno == EINTR { continue }
                    guard n > 0 else { throw Failure("Socket write failed") }; offset += n
                }
            }
            var framer = LineBuffer(limit: 16 * 1024 * 1024)
            var chunk = [UInt8](repeating: 0, count: 65536)
            while true {
                let n = read(fd, &chunk, chunk.count)
                if n < 0 && errno == EINTR { continue }
                guard n > 0 else { throw Failure(n == 0 ? "Truncated RPC response" : "RPC read timed out or failed") }
                let lines = try framer.append(Data(chunk.prefix(n)))
                if let line = lines.first {
                    let response = try JSONDecoder().decode(JSON.self, from: line)
                    guard response["id"].string == id else { throw Failure("Mismatched RPC response") }
                    if response["error"] != .null { throw Failure(response["error"]["message"].string ?? "RPC error") }
                    guard response["result"] != .null else { throw Failure("Missing RPC result") }
                    return response["result"]
                }
            }
        }.value
    }
}

/// Events invalidate the cache; they are never replayed over an authoritative snapshot.
/// The single buffered signal coalesces bursts without losing the need to refresh.
public final class EventFeed: @unchecked Sendable {
    public let signals: AsyncThrowingStream<Void, Error>
    private let state: State
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var fd: Int32 = -1
        var stopped = false
        func stop() {
            lock.lock(); defer { lock.unlock() }
            stopped = true
            if fd >= 0 { shutdown(fd, SHUT_RDWR) }
        }
    }
    public init(path: String, panes: [String]) {
        let state = State(); self.state = state
        signals = AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            continuation.onTermination = { _ in state.stop() }
            DispatchQueue.global(qos: .utility).async {
                let fd = socket(AF_UNIX, SOCK_STREAM, 0)
                guard fd >= 0 else { continuation.finish(throwing: Failure("Cannot subscribe")); return }
                state.lock.lock(); state.fd = fd; let stopped = state.stopped; state.lock.unlock()
                defer { state.lock.lock(); state.fd = -1; close(fd); state.lock.unlock() }
                guard !stopped else { continuation.finish(); return }
                do {
                    _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
                    var noPipe: Int32 = 1
                    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noPipe, 4)
                    var timeout = timeval(tv_sec: 1, tv_usec: 0)
                    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
                    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
                    var address = sockaddr_un(); address.sun_family = sa_family_t(AF_UNIX)
                    let bytes = Array(path.utf8)
                    guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw Failure("Socket path is too long") }
                    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
                    let result = withUnsafePointer(to: &address) { p in p.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
                    guard result == 0 else { throw Failure("Event connection failed") }
                    let kinds = ["workspace.created", "workspace.updated", "workspace.metadata_updated", "workspace.renamed", "workspace.moved", "workspace.reordered", "workspace.closed", "tab.created", "tab.closed", "tab.renamed", "tab.moved", "pane.created", "pane.closed", "pane.updated", "pane.moved", "pane.exited", "pane.agent_detected", "layout.updated"]
                    let subscriptions = kinds.map { JSON.object(["type": .string($0)]) } + panes.map { JSON.object(["type": .string("pane.agent_status_changed"), "pane_id": .string($0)]) }
                    let request = try JSONEncoder().encode(JSON.object(["id": .string("events"), "method": .string("events.subscribe"), "params": .object(["subscriptions": .array(subscriptions)])])) + Data([10])
                    try request.withUnsafeBytes { bytes in
                        var offset = 0
                        while offset < bytes.count {
                            let count = write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                            if count < 0 && errno == EINTR { continue }
                            guard count > 0 else { throw Failure("Subscription write failed") }; offset += count
                        }
                    }
                    var framer = LineBuffer(limit: 16 * 1024 * 1024), chunk = [UInt8](repeating: 0, count: 65536)
                    var acknowledged = false, lastSignal = Date()
                    while true {
                        state.lock.lock(); let stopped = state.stopped; state.lock.unlock()
                        if stopped { continuation.finish(); return }
                        let count = read(fd, &chunk, chunk.count)
                        if count < 0 && errno == EINTR { continue }
                        if count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) {
                            // Low-frequency reconciliation also catches changes lacking events.
                            if acknowledged && Date().timeIntervalSince(lastSignal) >= 10 { continuation.yield(()); lastSignal = Date() }
                            if !acknowledged && Date().timeIntervalSince(lastSignal) >= 15 { throw Failure("Subscription acknowledgement timed out") }
                            continue
                        }
                        guard count > 0 else { throw Failure("Event stream disconnected") }
                        for line in try framer.append(Data(chunk.prefix(count))) {
                            let value = try JSONDecoder().decode(JSON.self, from: line)
                            if value["error"] != .null { throw Failure(value["error"]["message"].string ?? "Event history lost") }
                            if !acknowledged {
                                guard value["id"].string == "events", value["result"] != .null else { throw Failure("Invalid subscription acknowledgement") }
                                acknowledged = true
                            }
                            continuation.yield(()); lastSignal = Date()
                        }
                    }
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
    public func stop() { state.stop() }
    deinit { stop() }
}

public struct LineBuffer: Sendable {
    private var data = Data()
    private let limit: Int
    public init(limit: Int = 2 * 1024 * 1024) { self.limit = limit }
    public mutating func append(_ chunk: Data) throws -> [Data] {
        data.append(chunk)
        var lines: [Data] = []
        while let end = data.firstIndex(of: 10) {
            guard data.distance(from: data.startIndex, to: end) <= limit else { throw Failure("RPC frame exceeds limit") }
            lines.append(Data(data[..<end])); data.removeSubrange(...end)
        }
        guard data.count <= limit else { throw Failure("RPC frame exceeds limit") }
        return lines
    }
}
