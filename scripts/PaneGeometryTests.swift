import Foundation
import CoreGraphics

@main struct PaneGeometryTests {
    static func main() {
        let layouts: [[CGRect]] = [
            [CGRect(x: 0, y: 0, width: 1, height: 1)],
            [CGRect(x: 0, y: 0, width: 0.37, height: 1), CGRect(x: 0.37, y: 0, width: 0.63, height: 1)],
            [CGRect(x: 0, y: 0, width: 1, height: 0.41), CGRect(x: 0, y: 0.41, width: 1, height: 0.59)],
            [CGRect(x: 0, y: 0, width: 0.53, height: 0.43), CGRect(x: 0, y: 0.43, width: 0.53, height: 0.57), CGRect(x: 0.53, y: 0, width: 0.47, height: 1)],
            [CGRect(x: 0, y: 0, width: 0.5, height: 0.5), CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5), CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5), CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)]
        ]
        func equal(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.00001 }
        for scale: CGFloat in [1, 2] {
            precondition(PaneMetrics.borderWidth(scale: scale) == (scale == 2 ? 1.5 : 2))
            for size in [CGSize(width: 719, height: 585), CGSize(width: 997.5, height: 725.5)] {
                for layout in layouts {
                    let frames = layout.map { PaneMetrics.frame($0, in: size, scale: scale) }
                    for (i, rect) in layout.enumerated() {
                        let frame = frames[i], border = PaneMetrics.borderFrame(frame, scale: scale)
                        precondition(frame.width > 0 && frame.height > 0)
                        precondition(frame.contains(border), "Independent border escaped pane frame")
                        let half = PaneMetrics.borderWidth(scale: scale) / 2
                        for edge in [border.minX - half, border.maxX + half, border.minY - half, border.maxY + half] {
                            precondition(equal(edge * scale, (edge * scale).rounded()), "Stroke is not aligned to backing pixels")
                        }
                        if rect.minX == 0 { precondition(frame.minX == 0, "Left canvas edge moved") }
                        if rect.maxY == 1 { precondition(frame.minY == 0, "Bottom canvas edge moved") }
                        for j in layout.indices where j > i {
                            let other = layout[j], next = frames[j]
                            precondition(!frame.intersects(next), "Pane frames overlap")
                            if equal(rect.maxX, other.minX), min(rect.maxY, other.maxY) > max(rect.minY, other.minY) {
                                precondition(equal(next.minX - frame.maxX, 8), "Horizontal gutter changed")
                            }
                            if equal(rect.maxY, other.minY), min(rect.maxX, other.maxX) > max(rect.minX, other.minX) {
                                precondition(equal(frame.minY - next.maxY, 8), "Vertical gutter changed")
                            }
                        }
                    }
                }
            }
        }
        let tiny = PaneMetrics.frame(CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), in: CGSize(width: 2, height: 2), scale: 2)
        precondition(tiny.width >= 0 && tiny.height >= 0, "Tiny layout produced a negative frame")
        print("PASS: independent pane borders, 8pt gutters, nested/stacked/grid layouts, resize, 1×/2× pixel alignment and outer canvas edges")
    }
}
