import Foundation
import CoreGraphics

/// Presentation insets around Herdr's authoritative, normalized pane rectangles.
enum PaneMetrics {
    static let contentInset: CGFloat = 4
    static let headerHeight: CGFloat = 24
    static let splitGap: CGFloat = 8
    static let edgeInset: CGFloat = 8
    static func borderWidth(scale: CGFloat) -> CGFloat { (1.5 * scale).rounded() / scale }
    static let horizontalOverhead = contentInset * 2
    static let verticalOverhead = headerHeight + contentInset

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
        // Align both edges of the stroke to backing pixels, including on 1× displays.
        let top = ((frame.maxY - 11 - inset) * scale).rounded() / scale + inset
        return CGRect(x: frame.minX + inset, y: frame.minY + inset,
                      width: max(0, frame.width - width),
                      height: max(0, top - frame.minY - inset))
    }
}
