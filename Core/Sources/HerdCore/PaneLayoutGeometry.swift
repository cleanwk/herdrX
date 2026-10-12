import Foundation

/// Herdr's pane rectangles use the same absolute cell coordinates as `area`.
/// The GUI canvas has its own origin and must not inherit the TUI's chrome offset.
public enum PaneLayoutGeometry {
    public static func normalizedRect(_ rect: JSON, in area: JSON) -> CGRect? {
        guard let width = area["width"].int, let height = area["height"].int,
              width > 0, height > 0 else { return nil }
        let originX = area["x"].int ?? 0, originY = area["y"].int ?? 0
        let x = rect["x"].int ?? originX, y = rect["y"].int ?? originY
        return CGRect(x: (Double(x) - Double(originX)) / Double(width),
                      y: (Double(y) - Double(originY)) / Double(height),
                      width: Double(rect["width"].int ?? width) / Double(width),
                      height: Double(rect["height"].int ?? height) / Double(height))
    }
}
