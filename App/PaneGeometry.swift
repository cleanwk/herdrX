import Foundation
import CoreGraphics

/// Presentation insets around Herdr's authoritative, normalized pane rectangles.
enum PaneMetrics {
    static let contentInset: CGFloat = 4
    static let headerHeight: CGFloat = 24
    static let splitGap: CGFloat = 6
    static let edgeInset: CGFloat = 3
    static let titleOffset: CGFloat = 7
    static let titleLeading: CGFloat = 9
    static let titlePadding: CGFloat = 5
    static let titleGap: CGFloat = 5
    static func borderWidth(scale: CGFloat) -> CGFloat { 1 }
    static let horizontalOverhead = contentInset * 2
    static let verticalOverhead = headerHeight + contentInset

    static func canSplit(_ size: CGSize, horizontal: Bool, minimum: CGSize) -> Bool {
        let dimension = horizontal ? size.width : size.height
        let required = horizontal ? minimum.width : minimum.height
        return dimension > 0 && dimension >= required * 2 - splitGap
    }

    static func frame(_ rect: CGRect, in size: CGSize, scale: CGFloat) -> CGRect {
        func snap(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
        let left = snap(size.width * rect.minX), right = snap(size.width * rect.maxX)
        let bottom = snap(size.height * (1 - rect.maxY)), top = snap(size.height * (1 - rect.minY))
        // Each neighbor contributes half the gutter. The workbench insets the whole canvas.
        let dx = min(splitGap / 2, max(0, right - left) / 2)
        let dy = min(splitGap / 2, max(0, top - bottom) / 2)
        let x = left + (rect.minX > 0.001 ? dx : 0)
        let y = bottom + (rect.maxY < 0.999 ? dy : 0)
        return CGRect(x: x, y: y,
                      width: max(0, right - (rect.maxX < 0.999 ? dx : 0) - x),
                      height: max(0, top - (rect.minY > 0.001 ? dy : 0) - y))
    }

    static func borderFrame(_ frame: CGRect, scale: CGFloat) -> CGRect {
        let width = borderWidth(scale: scale)
        let inset = width / 2
        // A 1pt inside stroke is pixel-aligned at both 1× and 2×.
        return CGRect(x: frame.minX + inset, y: frame.minY + inset,
                      width: max(0, frame.width - width),
                      height: max(0, frame.height - titleOffset - width))
    }
}

/// Radii at the canvas boundary, before the stroke or terminal content inset.
struct PaneCorners: Equatable {
    var left: CGFloat = 0
    var right: CGFloat = 0

    func inset(by amount: CGFloat) -> Self {
        Self(left: max(0, left - amount), right: max(0, right - amount))
    }

    func forPane(_ rect: CGRect, fullScreen: Bool) -> Self {
        guard !fullScreen, rect.maxY > 0.999 else { return Self() }
        return Self(left: rect.minX < 0.001 ? left : 0,
                    right: rect.maxX > 0.999 ? right : 0)
    }
}
