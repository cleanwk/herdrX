import XCTest
@testable import HerdCore
final class TabOrderTests: XCTestCase {
    func testFailedFirstMoveKeepsLaterIntent() {
        var order = TabOrder(["a", "b", "c", "d"])
        order.enqueue(source: "a", insertion: 4)
        order.enqueue(source: "c", insertion: 0)
        XCTAssertEqual(order.visible, ["c", "b", "d", "a"])
        let first = order.pending[0].id
        order.complete(first, server: nil)
        XCTAssertEqual(order.visible, ["c", "a", "b", "d"])
        order.complete(first, server: ["bad"])
        XCTAssertEqual(order.visible, ["c", "a", "b", "d"])
        order.complete(order.pending[0].id, server: ["c", "a", "b", "d"])
        XCTAssertTrue(order.pending.isEmpty)
    }
}
