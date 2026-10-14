import XCTest
@testable import HerdCore

final class TerminalScrollTests: XCTestCase {
    func testPreciseMotionAccumulatesAndReversesWithoutAnOppositeStep() {
        var scroll = TerminalScroll()
        XCTAssertEqual(scroll.lines(delta: 3, precise: true, lineHeight: 12), 0)
        XCTAssertEqual(scroll.lines(delta: 3, precise: true, lineHeight: 12), 0)
        XCTAssertEqual(scroll.lines(delta: 7, precise: true, lineHeight: 12), 1)
        XCTAssertEqual(scroll.lines(delta: -6, precise: true, lineHeight: 12), 0)
        XCTAssertEqual(scroll.lines(delta: -6, precise: true, lineHeight: 12), -1)
    }
    func testDiscreteWheelAndMomentumUseBoundedHistoryOffsets() {
        var scroll = TerminalScroll()
        XCTAssertEqual(scroll.lines(delta: 1, precise: false, lineHeight: 18), 3)
        XCTAssertEqual(scroll.lines(delta: -1, precise: false, lineHeight: 18), -3)
        XCTAssertEqual(TerminalScroll.offset(current: 2, maximum: 5, lines: 9), 5)
        XCTAssertEqual(TerminalScroll.offset(current: 2, maximum: 5, lines: -9), 0)
        XCTAssertEqual(TerminalScroll.offset(current: Int.max - 1, maximum: Int.max, lines: Int.max), Int.max)
        XCTAssertEqual(TerminalScroll.offset(current: 0, maximum: 5, lines: Int.min), 0)
        XCTAssertEqual(scroll.lines(delta: .infinity, precise: true, lineHeight: 18), 0)
        XCTAssertEqual(scroll.lines(delta: 1, precise: true, lineHeight: 0), 0)
    }
}
