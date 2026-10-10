import XCTest
@testable import HerdCore

final class FileTests: XCTestCase {
    func temporary() throws -> URL { let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url }
    func testPreviewLimitsHiddenFilesAndLinks() async throws {
        let dir = try temporary(); defer { try? FileManager.default.removeItem(at: dir) }
        for (name, size) in [("empty.txt", 0), ("limit.txt", FileService.previewLimit), ("over.txt", FileService.previewLimit + 1), (".hidden", 1)] { try Data(repeating: 65, count: size).write(to: dir.appendingPathComponent(name)) }
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("link"), withDestinationURL: dir.appendingPathComponent("limit.txt"))
        let service = FileService()
        let empty = try await service.preview(dir.appendingPathComponent("empty.txt").path)
        XCTAssertEqual(empty.count, 0)
        let limit = try await service.preview(dir.appendingPathComponent("limit.txt").path)
        XCTAssertEqual(limit.count, FileService.previewLimit)
        for name in ["over.txt", "link"] { do { _ = try await service.preview(dir.appendingPathComponent(name).path); XCTFail("Must reject \(name)") } catch {} }
        let rows = try await service.list(dir.path); XCTAssertEqual(rows.count, 4)
        let hidden = try await service.list(dir.path, hidden: true); XCTAssertEqual(hidden.count, 5)
    }
    func testConflictPoliciesAndCancellationPreserveDestination() async throws {
        let dir = try temporary(); defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("source"), dest = dir.appendingPathComponent("dest")
        try Data(repeating: 66, count: 300000).write(to: source); try Data("old".utf8).write(to: dest)
        let service = FileService()
        do { _ = try await service.transfer(source.path, to: service, destination: dest.path, conflict: .cancel); XCTFail("Must not overwrite") } catch {}
        XCTAssertEqual(try Data(contentsOf: dest), Data("old".utf8))
        let copy = try await service.transfer(source.path, to: service, destination: dest.path, conflict: .keepBoth)
        XCTAssertNotEqual(copy, dest.path); XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: copy)), try Data(contentsOf: source))
        let task = Task { try await service.transfer(source.path, to: service, destination: dest.path, conflict: .replace) { _, _ in withUnsafeCurrentTask { $0?.cancel() } } }
        do { _ = try await task.value; XCTFail("Cancellation must propagate") } catch is CancellationError {} catch { XCTFail("\(error)") }
        XCTAssertEqual(try Data(contentsOf: dest), Data("old".utf8))
        _ = try await service.transfer(source.path, to: service, destination: dest.path, conflict: .replace)
        XCTAssertEqual(try Data(contentsOf: dest), try Data(contentsOf: source))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: dir.path).contains { $0.hasSuffix(".part") })
    }
}

extension FileTests {
    func testIsolatedSSHTransferWhenConfigured() async throws {
        guard let config = ProcessInfo.processInfo.environment["HERDRX_TEST_SSH_CONFIG"], (config.hasPrefix("/tmp/herdrx-") || config.hasSuffix("/herdrX/build/ssh-fixture/config")) else { throw XCTSkip("No isolated SSH fixture configured") }
        let dir = try temporary(); defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("中文 source.txt"), dest = dir.appendingPathComponent("remote.txt")
        try Data(repeating: 65, count: 280000).write(to: source)
        let local = FileService(), ssh = FileService(endpoint: .init(kind: "ssh", target: "parity-fixture", port: 42891, socketPath: "", sshConfig: config))
        _ = try await local.transfer(source.path, to: ssh, destination: dest.path, conflict: .cancel)
        let remoteData = try await ssh.preview(dest.path)
        XCTAssertEqual(remoteData, try Data(contentsOf: source))
        do { _ = try await local.transfer(source.path, to: ssh, destination: dest.path, conflict: .cancel); XCTFail("SSH must not overwrite") } catch {}
        let kept = try await local.transfer(source.path, to: ssh, destination: dest.path, conflict: .keepBoth)
        XCTAssertNotEqual(kept, dest.path)
        let cancelled = Task { try await local.transfer(source.path, to: ssh, destination: dest.path, conflict: .replace) { _, _ in withUnsafeCurrentTask { $0?.cancel() } } }
        do { _ = try await cancelled.value; XCTFail("SSH cancellation must propagate") } catch is CancellationError {} catch { XCTFail("\(error)") }
        let preserved = try await ssh.preview(dest.path); XCTAssertEqual(preserved, remoteData)
        let entries = try await ssh.list(dir.path, hidden: true); XCTAssertFalse(entries.contains { $0.name.hasSuffix(".part") })
        let download = dir.appendingPathComponent("download.txt")
        _ = try await ssh.transfer(dest.path, to: local, destination: download.path, conflict: .cancel)
        XCTAssertEqual(try Data(contentsOf: download), remoteData)
    }
}
