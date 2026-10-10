import SwiftUI

/// The same continuous contour draws the outline and clips opaque terminal pixels.
enum PaneShape {
    static func path(in rect: CGRect, corners: PaneCorners) -> CGPath {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: corners.left,
                                           bottomTrailingRadius: corners.right, style: .continuous)
        let path = shape.path(in: CGRect(origin: .zero, size: rect.size)).cgPath
        // SwiftUI shapes use a top-left origin; the native canvas uses a bottom-left origin.
        var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: rect.minX, ty: rect.maxY)
        return path.copy(using: &transform)!
    }
}
