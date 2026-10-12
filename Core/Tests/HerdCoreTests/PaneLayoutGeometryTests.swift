import Foundation
import CoreGraphics
import XCTest
@testable import HerdCore

final class PaneLayoutGeometryTests: XCTestCase {
    private func box(_ x: Int, _ y: Int, _ width: Int, _ height: Int) -> JSON {
        .object(["x": .number(Double(x)), "y": .number(Double(y)),
                 "width": .number(Double(width)), "height": .number(Double(height))])
    }

    func testSinglePaneFillsCanvasRegardlessOfTUISidebarAndHeaderOrigin() {
        for area in [box(0, 0, 80, 24), box(27, 2, 53, 22), box(40, 3, 80, 30), box(48, 2, 112, 38)] {
            XCTAssertEqual(PaneLayoutGeometry.normalizedRect(area, in: area), CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    func testNestedSplitsKeepTheirRatiosAndTUIChromeInsetsWhenOriginMoves() {
        let leaves = [(1, 1, 58, 37), (61, 1, 138, 18), (61, 21, 138, 17)]
        let zero = box(0, 0, 200, 40)
        for (dx, dy) in [(27, 2), (48, 3), (0, 5)] {
            let area = box(dx, dy, 200, 40)
            for (x, y, width, height) in leaves {
                let expected = PaneLayoutGeometry.normalizedRect(box(x, y, width, height), in: zero)
                let actual = PaneLayoutGeometry.normalizedRect(box(x + dx, y + dy, width, height), in: area)
                XCTAssertEqual(actual, expected)
                XCTAssertTrue(CGRect(x: 0, y: 0, width: 1, height: 1).contains(actual!))
            }
        }
    }

    func testLegacyMissingOriginsAndMissingPaneDimensionsRemainSupported() {
        let area: JSON = .object(["width": .number(80), "height": .number(24)])
        XCTAssertEqual(PaneLayoutGeometry.normalizedRect(box(0, 0, 40, 12), in: area), CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        XCTAssertEqual(PaneLayoutGeometry.normalizedRect(.object([:]), in: box(27, 2, 53, 22)), CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    func testUnavailableOrEmptyAreaDoesNotProduceInvalidGeometry() {
        for area in [JSON.null, box(0, 0, 0, 24), box(0, 0, 80, 0), box(0, 0, -1, 24)] {
            XCTAssertNil(PaneLayoutGeometry.normalizedRect(box(1, 1, 10, 10), in: area))
        }
    }
}
