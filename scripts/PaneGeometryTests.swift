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
            precondition(PaneMetrics.borderWidth(scale: scale) == 1)
            for size in [CGSize(width: 719, height: 585), CGSize(width: 997.5, height: 725.5)] {
                for layout in layouts {
                    let frames = layout.map { PaneMetrics.frame($0, in: size, scale: scale) }
                    for (i, rect) in layout.enumerated() {
                        let frame = frames[i], border = PaneMetrics.borderFrame(frame, scale: scale)
                        precondition(frame.width > 0 && frame.height > 0)
                        precondition(frame.contains(border), "Independent border escaped pane frame")
                        let half = PaneMetrics.borderWidth(scale: scale) / 2
                        precondition(equal(frame.maxY - border.maxY - half, 7), "Top outline offset changed")
                        for edge in [border.minX - half, border.maxX + half, border.minY - half, border.maxY + half] {
                            precondition(equal(edge * scale, (edge * scale).rounded()), "Stroke is not aligned to backing pixels")
                        }
                        if rect.minX == 0 { precondition(frame.minX == 0, "Left canvas edge moved") }
                        if rect.maxY == 1 { precondition(frame.minY == 0, "Bottom canvas edge moved") }
                        for j in layout.indices where j > i {
                            let other = layout[j], next = frames[j]
                            precondition(!frame.intersects(next), "Pane frames overlap")
                            if equal(rect.maxX, other.minX), min(rect.maxY, other.maxY) > max(rect.minY, other.minY) {
                                precondition(equal(next.minX - frame.maxX, 6), "Horizontal gutter changed")
                                let nextBorder = PaneMetrics.borderFrame(next, scale: scale)
                                precondition(equal(nextBorder.minX - border.maxX - 2 * half, 6), "Horizontal border gap changed")
                            }
                            if equal(rect.maxY, other.minY), min(rect.maxX, other.maxX) > max(rect.minX, other.minX) {
                                precondition(equal(frame.minY - next.maxY, 6), "Vertical gutter changed")
                                let nextBorder = PaneMetrics.borderFrame(next, scale: scale)
                                precondition(equal(border.minY - nextBorder.maxY - 2 * half, 13), "Vertical border gap changed")
                            }
                        }
                    }
                }
            }
        }
        let outer = PaneCorners(left: 12, right: 12)
        let left = CGRect(x: 0, y: 0, width: 0.5, height: 1)
        let right = CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        let upper = CGRect(x: 0, y: 0, width: 1, height: 0.5)
        let lower = CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        precondition(outer.forPane(left, fullScreen: false) == PaneCorners(left: 12))
        precondition(outer.forPane(right, fullScreen: false) == PaneCorners(right: 12))
        precondition(outer.forPane(upper, fullScreen: false) == PaneCorners())
        precondition(outer.forPane(lower, fullScreen: false) == outer)
        precondition(outer.forPane(lower, fullScreen: true) == PaneCorners())
        let sidebar = PaneCorners(right: 12)
        precondition(sidebar.forPane(left, fullScreen: false) == PaneCorners())
        precondition(sidebar.forPane(right, fullScreen: false) == sidebar)
        precondition(outer.inset(by: 0.5) == PaneCorners(left: 11.5, right: 11.5))
        precondition(outer.inset(by: 4) == PaneCorners(left: 8, right: 8))
        precondition(outer.inset(by: 20) == PaneCorners())
        let shape = CGRect(x: 0, y: 0, width: 300, height: 200)
        let curved = PaneShape.path(in: shape, corners: PaneCorners(left: 12))
        precondition(!curved.contains(CGPoint(x: 0.1, y: 0.1)), "Outer bottom corner is still square")
        precondition(curved.contains(CGPoint(x: 0.1, y: 199.9)), "Top corner was rounded")
        precondition(curved.contains(CGPoint(x: 299.9, y: 0.1)), "Internal bottom corner was rounded")
        precondition(PaneShape.path(in: shape, corners: PaneCorners()).contains(CGPoint(x: 0.1, y: 0.1)), "Full-screen or internal corner is not square")
        let tiny = PaneMetrics.frame(CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), in: CGSize(width: 2, height: 2), scale: 2)
        precondition(tiny.width >= 0 && tiny.height >= 0, "Tiny layout produced a negative frame")
        let minimum = CGSize(width: 226.6, height: 157.5)
        let canvas = CGSize(width: 703, height: 583)
        let smallPane = PaneMetrics.frame(CGRect(x: 0, y: 0, width: 0.3, height: 1), in: canvas, scale: 2)
        precondition(!PaneMetrics.canSplit(smallPane.size, horizontal: true, minimum: minimum), "A narrow pane permits an undersized horizontal split")
        precondition(PaneMetrics.canSplit(smallPane.size, horizontal: false, minimum: minimum), "A tall pane cannot split down")
        precondition(PaneMetrics.canSplit(canvas, horizontal: true, minimum: minimum), "A full-size pane cannot split right")
        precondition(!PaneMetrics.canSplit(.zero, horizontal: false, minimum: minimum), "An unlaid-out pane can split")
        for horizontal in [false, true] {
            let threshold = (horizontal ? minimum.width : minimum.height) * 2 - PaneMetrics.splitGap
            let fits = horizontal ? CGSize(width: threshold, height: 583) : CGSize(width: 703, height: threshold)
            let short = horizontal ? CGSize(width: threshold - 0.5, height: 583) : CGSize(width: 703, height: threshold - 0.5)
            precondition(PaneMetrics.canSplit(fits, horizontal: horizontal, minimum: minimum))
            precondition(!PaneMetrics.canSplit(short, horizontal: horizontal, minimum: minimum))
        }
        print("PASS: 1pt inside borders, 6pt horizontal / 13pt vertical border gaps, 7pt top offset, nested/stacked/grid layouts, resize, 1×/2× pixel alignment, outer canvas edges, selective continuous corners and concentric terminal masks")
    }
}
