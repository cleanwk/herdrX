import Foundation

final class Capture: @unchecked Sendable {
    private let lock = NSLock()
    private var value = ""
    func append(_ bytes: Data) { lock.lock(); value += String(decoding: bytes, as: UTF8.self); lock.unlock() }
    func clear() { lock.lock(); value = ""; lock.unlock() }
    func read() -> String { lock.lock(); defer { lock.unlock() }; return value }
}

@main struct PTYStress {
    static func main() async throws {
        let process = ByteProcess(), output = Capture()
        process.output = { output.append($0) }
        for round in 0..<20 {
            process.start("exec /bin/sh -c 'while :; do printf OLD; done'")
            try await Task.sleep(nanoseconds: 10_000_000)
            process.start("exec /bin/cat")
            output.clear()
            process.write(Data("NEW-\(round)\n".utf8))
            try await Task.sleep(nanoseconds: 80_000_000)
            let text = output.read()
            guard !text.contains("OLD"), text.contains("NEW-\(round)") else {
                process.stop(); fatalError("PTY generation isolation failed in round \(round)")
            }
        }
        process.stop()
        print("PASS: 20 actual PTY restart/output/write generations; no previous-run bytes after restart")
    }
}
