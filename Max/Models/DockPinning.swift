import CoreGraphics

/// Keeps the Dock on one display by stopping the pointer just short of the Dock edge of every other display, where
/// pushing against it would summon the Dock. Rects are in CoreGraphics global coordinates (origin at the primary
/// display's top-left corner, y growing downward), as event taps report them.
nonisolated enum DockPinning {
    /// How close to an edge the pointer may get.
    static let edgeDepth: CGFloat = 2

    /// Strips along the Dock edge of every display except the pinned one, leaving out stretches where another
    /// display continues past the edge: the pointer has to cross those, and the Dock cannot be summoned there.
    static func blockedEdges(displays: [CGRect], pinned: Int, orientation: DockOrientation) -> [CGRect] {
        displays.indices.filter { $0 != pinned }.flatMap { index -> [CGRect] in
            let display = displays[index]
            let others = displays.indices.filter { $0 != index }.map { displays[$0] }
            switch orientation {
            case .bottom:
                let open = subtract(from: display.minX..<display.maxX, others.filter { abs($0.minY - display.maxY) < 1 }.map { $0.minX..<$0.maxX })
                return open.map { CGRect(x: $0.lowerBound, y: display.maxY - edgeDepth, width: $0.upperBound - $0.lowerBound, height: edgeDepth) }
            case .left:
                let open = subtract(from: display.minY..<display.maxY, others.filter { abs($0.maxX - display.minX) < 1 }.map { $0.minY..<$0.maxY })
                return open.map { CGRect(x: display.minX, y: $0.lowerBound, width: edgeDepth, height: $0.upperBound - $0.lowerBound) }
            case .right:
                let open = subtract(from: display.minY..<display.maxY, others.filter { abs($0.minX - display.maxX) < 1 }.map { $0.minY..<$0.maxY })
                return open.map { CGRect(x: display.maxX - edgeDepth, y: $0.lowerBound, width: edgeDepth, height: $0.upperBound - $0.lowerBound) }
            }
        }
    }

    /// Where the pointer goes instead when `point` falls in a blocked strip: just outside it, back toward the display.
    static func clamped(_ point: CGPoint, edges: [CGRect], orientation: DockOrientation) -> CGPoint? {
        guard let edge = edges.first(where: { $0.contains(point) }) else { return nil }
        switch orientation {
        case .bottom: return CGPoint(x: point.x, y: edge.minY - 0.5)
        case .left: return CGPoint(x: edge.maxX + 0.5, y: point.y)
        case .right: return CGPoint(x: edge.minX - 0.5, y: point.y)
        }
    }

    /// The parts of `range` no hole covers.
    static func subtract(from range: Range<CGFloat>, _ holes: [Range<CGFloat>]) -> [Range<CGFloat>] {
        holes.reduce([range]) { pieces, hole in
            pieces.flatMap { piece -> [Range<CGFloat>] in
                guard piece.overlaps(hole) else { return [piece] }
                var rest: [Range<CGFloat>] = []
                if piece.lowerBound < hole.lowerBound { rest.append(piece.lowerBound..<hole.lowerBound) }
                if hole.upperBound < piece.upperBound { rest.append(hole.upperBound..<piece.upperBound) }
                return rest
            }
        }
    }
}
