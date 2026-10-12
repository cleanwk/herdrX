import XCTest
@testable import HerdCore

final class HerdrMachinesTests: XCTestCase {
    func catalog(_ rows: String) throws -> HerdrMachines { try HerdrMachines(data: Data(rows.utf8)) }
    let row = #"{"id":"acc-1","label":"ACC","target":"acc-alias","session":"agents","enabled":true}"#
    func testImportIsLocalAndNeedsNoSocketOrRunningSession() throws {
        let devices = try catalog("[" + row + "]").changes(to: []).added
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0].source, "herdr-machine:acc-1")
        XCTAssertEqual(devices[0].endpoint.session, "agents")
        XCTAssertEqual(devices[0].endpoint.socketPath, "")
        XCTAssertTrue(devices[0].endpoint.valid)
    }
    func testOnlyManagedDevicesAreReconciledAndIdentitySurvivesChanges() throws {
        let old = Device(id: "stable", displayName: "Old", endpoint: .init(kind: "ssh", target: "old", session: "old"), source: "herdr-machine:acc-1")
        let manual = Device(id: "herdr-machine.manual", displayName: "Manual", endpoint: .init(kind: "ssh", target: "acc-alias", session: "agents"))
        let removed = Device(id: "gone", displayName: "Gone", endpoint: old.endpoint, source: "herdr-machine:gone")
        let changes = try catalog("[" + row + "]").changes(to: [old, manual, removed])
        XCTAssertEqual(changes.removed, ["gone"])
        XCTAssertEqual(changes.updated.map(\.id), ["stable"])
        XCTAssertEqual(changes.updated[0].displayName, "ACC")
        XCTAssertEqual(changes.updated[0].endpoint.target, "acc-alias")
        XCTAssertEqual(changes.updated[0].endpoint.session, "agents")
        XCTAssertTrue(changes.added.isEmpty)
    }
    func testDisabledRemovedButOneShotImportNeverRemoves() throws {
        let old = try catalog("[" + row + "]").devices
        let disabled = try catalog(#"[{"id":"acc-1","enabled":false}]"#)
        XCTAssertEqual(disabled.changes(to: old).removed, old.map(\.id))
        XCTAssertTrue(disabled.changes(to: old, removeMissing: false).removed.isEmpty)
    }
    func testBadRowRetainsItsDeviceAndDoesNotBlockOtherImports() throws {
        let old = try catalog("[" + row + "]").devices
        let partial = try catalog(#"[{"id":"acc-1","enabled":true,"target":""},"#.appending(row.replacingOccurrences(of: "acc-1", with: "acc-2")) + "]")
        let changes = partial.changes(to: old)
        XCTAssertEqual(changes.added.count, 1)
        XCTAssertTrue(changes.removed.isEmpty)
        XCTAssertTrue(changes.updated.isEmpty)
        XCTAssertEqual(partial.warnings, ["acc-1"])
    }
    func testUnreadableOrAmbiguousSnapshotCannotProduceDeletionPlan() throws {
        for value in ["", "broken", "{}", "null", "[{}]", "[" + row + "," + row + "]"] { XCTAssertThrowsError(try catalog(value)) }
    }
    func testManualIDCollisionCreatesSeparateManagedDevice() throws {
        let manual = Device(id: "herdr-machine.acc-1", displayName: "Manual", endpoint: .init(kind: "local", socketPath: "/tmp/manual.sock"))
        let changes = try catalog("[" + row + "]").changes(to: [manual])
        XCTAssertEqual(changes.added.count, 1); XCTAssertNotEqual(changes.added[0].id, manual.id)
        XCTAssertTrue(changes.removed.isEmpty); XCTAssertTrue(changes.updated.isEmpty)
    }
    func testLegacyOwnershipMigrationAndExplicitManualRoundTrip() throws {
        let legacy = #"{"id":"herdr-machine.acc-1","displayName":"ACC","endpoint":{"kind":"ssh","target":"host","socketPath":"/old.sock"}}"#
        let device = try JSONDecoder().decode(Device.self, from: Data(legacy.utf8))
        XCTAssertEqual(device.source, "herdr-machine:acc-1")
        var manual = device; manual.source = nil
        XCTAssertNil(try JSONDecoder().decode(Device.self, from: JSONEncoder().encode(manual)).source)
        let named = try JSONDecoder().decode(Device.Endpoint.self, from: Data(#"{"kind":"ssh","target":"host","session":"agents"}"#.utf8))
        XCTAssertEqual(named.socketPath, ""); XCTAssertTrue(named.valid)
    }
    func testSessionDraftRoundTripAndUnsafeEndpoints() throws {
        let source = try catalog("[" + row + "]").devices[0]
        XCTAssertEqual(try ConnectionDraft(source).device(), source)
        for name in ["../escape", "x\nserver", "", "..", "$(whoami)"] { XCTAssertFalse(Device.Endpoint.validSession(name)) }
        XCTAssertFalse(Device.Endpoint(kind: "ssh", target: "-proxy", session: "agents").valid)
        XCTAssertFalse(Device.Endpoint(kind: "local", session: "agents").valid)
    }
}
