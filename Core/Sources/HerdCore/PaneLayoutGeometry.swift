import Foundation
import CoreGraphics

/// Herdr's pane rectangles use the same absolute cell coordinates as `area`.
/// The GUI canvas has its own origin and must not inherit the TUI's chrome offset.
public enum PaneLayoutGeometry {
    public static func normalizedRect(_ rect: JSON, in area: JSON) -> CGRect? {
        guard let width = area["width"].int, let height = area["height"].int,
              width > 0, height > 0 else { return nil }
        let originX = area["x"].int ?? 0, originY = area["y"].int ?? 0
        let x = rect["x"].int ?? originX, y = rect["y"].int ?? originY
        let normalizedX = (CGFloat(x) - CGFloat(originX)) / CGFloat(width)
        let normalizedY = (CGFloat(y) - CGFloat(originY)) / CGFloat(height)
        let normalizedWidth = CGFloat(rect["width"].int ?? width) / CGFloat(width)
        let normalizedHeight = CGFloat(rect["height"].int ?? height) / CGFloat(height)
        return CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
    }
}
