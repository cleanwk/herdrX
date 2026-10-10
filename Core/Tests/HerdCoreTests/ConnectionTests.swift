import XCTest
import Darwin
@testable import HerdCore

final class ConnectionTests: XCTestCase {
    func testLaunchOnlyTargetsCanonicalLocalSessions() {
        let home = "/Users/test"
        let root = home + "/.config/herdr"
        func target(_ path: String, kind: String = "local") -> LocalHerdrTarget? {
            LocalHerdrTarget(endpoint: .init(kind: kind, socketPath: path), home: home)
        }
        XCTAssertEqual(target(root + "/herdr.sock")?.arguments, ["server"])
        XCTAssertEqual(target(root + "/sessions/work/herdr.sock")?.arguments, ["--session", "work", "server"])
        XCTAssertEqual(target(root + "/sessions/work.v2-1_test/herdr.sock")?.arguments, ["--session", "work.v2-1_test", "server"])
        for path in [root + "/sessions/a'$(echo nope)/herdr.sock", root + "/sessions/invalid name/herdr.sock", "/tmp/custom.sock", root + "/sessions/../herdr.sock", root + "/sessions/a/b/herdr.sock", root + "/sessions/default/herdr.sock", root + "/sessions/" + String(repeating: "a", count: 65) + "/herdr.sock", root + "/sessions//herdr.sock", root + "/sessions/a\nb/herdr.sock"] {
            XCTAssertNil(target(path), path)
        }
        XCTAssertEqual(target(root + "/sessions/-flag/herdr.sock")?.arguments, ["--session", "-flag", "server"])
        XCTAssertNil(target(root + "/herdr.sock", kind: "ssh"))
        XCTAssertNil(target(root + "/herdr.sock", kind: "tailcat"))
    }

    func testMissingSocketRetainsTypedCauseForRecovery() async {
        let path = "/tmp/herdrx-missing-" + UUID().uuidString + ".sock"
        do { _ = try await RPC(path: path).call("session.snapshot"); XCTFail("Missing socket succeeded") }
        catch let error as SocketConnectionError {
            XCTAssertEqual(error.code, ENOENT)
            XCTAssertEqual(error.path, path)
            XCTAssertEqual(ConnectionIssue(error: error, endpoint: .init(kind: "local", socketPath: path)).kind, .localUnavailable)
        } catch { XCTFail("Lost socket failure code: \(error)") }
    }

    func testLocalStoppedDoesNotHidePermissionOrRemoteFailures() {
        let endpoint = Device.Endpoint(kind: "local", socketPath: NSHomeDirectory() + "/.config/herdr/herdr.sock")
        for code in [ENOENT, ECONNREFUSED] {
            let issue = ConnectionIssue(error: SocketConnectionError(path: endpoint.socketPath, code: code), endpoint: endpoint)
            XCTAssertEqual(issue.kind, .localStopped)
            XCTAssertTrue(issue.canStart)
            XCTAssertTrue(issue.automaticallyRetries)
        }
        let denied = ConnectionIssue(error: SocketConnectionError(path: endpoint.socketPath, code: EACCES), endpoint: endpoint)
        XCTAssertFalse(denied.canStart)
        let remote = ConnectionIssue(error: SocketConnectionError(path: "/tmp/tunnel.sock", code: ENOENT), endpoint: .init(kind: "ssh", target: "host", socketPath: endpoint.socketPath))
        XCTAssertEqual(remote.kind, .unavailable)
        XCTAssertFalse(remote.canStart)
    }

    func testAuthenticationNeedsUserRecoveryButNetworkCanRetry() {
        let endpoint = Device.Endpoint(kind: "ssh", target: "host", socketPath: "/tmp/herdr.sock")
        let auth = ConnectionIssue(error: Failure("Permission denied (publickey)"), endpoint: endpoint)
        XCTAssertEqual(auth.kind, .authentication)
        XCTAssertFalse(auth.automaticallyRetries)
        XCTAssertFalse(auth.canStart)
        XCTAssertTrue(ConnectionIssue(error: Failure("Connection timed out"), endpoint: endpoint).automaticallyRetries)
    }

    @MainActor func testMissingCLIHasAnInstallRecoveryCause() {
        let target = LocalHerdrTarget(endpoint: .init(kind: "local", socketPath: NSHomeDirectory() + "/.config/herdr/herdr.sock"))!
        XCTAssertThrowsError(try LocalHerdrLaunch(target: target, searchPaths: [])) { error in
            XCTAssertTrue(error is LocalHerdrLaunch.MissingExecutable)
        }
    }

    @MainActor func testLaunchUsesCapturedSessionAndPreservesFailureDetails() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("herdrx-launch-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cli = directory.appendingPathComponent("herdr")
        try Data("#!/bin/sh\nprintf '%s\\n' \"$@\" >&2\nexit 7\n".utf8).write(to: cli)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: cli.path)
        let endpoint = Device.Endpoint(kind: "local", socketPath: NSHomeDirectory() + "/.config/herdr/sessions/herdrx-launch-test/herdr.sock")
        let launch = try LocalHerdrLaunch(target: XCTUnwrap(LocalHerdrTarget(endpoint: endpoint)), searchPaths: [directory.path])
        defer { if launch.process.isRunning { launch.process.terminate() } }
        for _ in 0..<100 where launch.process.isRunning { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(launch.process.isRunning)
        XCTAssertEqual(launch.process.terminationStatus, 7)
        XCTAssertEqual(launch.diagnostic, "--session\nherdrx-launch-test\nserver")
        XCTAssertNil(launch.process.environment?["HERDR_SOCKET_PATH"])
        XCTAssertNil(launch.process.environment?["HERDR_CONFIG_PATH"])
        XCTAssertEqual(launch.process.environment?["XDG_CONFIG_HOME"], NSHomeDirectory() + "/.config")
    }
}
