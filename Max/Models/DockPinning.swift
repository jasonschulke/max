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
            let open = openStretches(of: index, displays: displays, orientation: orientation)
            switch orientation {
            case .bottom:
                return open.map { CGRect(x: $0.lowerBound, y: display.maxY - edgeDepth, width: $0.upperBound - $0.lowerBound, height: edgeDepth) }
            case .left:
                return open.map { CGRect(x: display.minX, y: $0.lowerBound, width: edgeDepth, height: $0.upperBound - $0.lowerBound) }
            case .right:
                return open.map { CGRect(x: display.maxX - edgeDepth, y: $0.lowerBound, width: edgeDepth, height: $0.upperBound - $0.lowerBound) }
            }
        }
    }

    /// The stretches of a display's Dock edge that no other display continues past: the only places the pointer can
    /// push against that edge.
    static func openStretches(of index: Int, displays: [CGRect], orientation: DockOrientation) -> [Range<CGFloat>] {
        let display = displays[index]
        let others = displays.indices.filter { $0 != index }.map { displays[$0] }
        switch orientation {
        case .bottom:
            return subtract(from: display.minX..<display.maxX, others.filter { abs($0.minY - display.maxY) < 1 }.map { $0.minX..<$0.maxX })
        case .left:
            return subtract(from: display.minY..<display.maxY, others.filter { abs($0.maxX - display.minX) < 1 }.map { $0.minY..<$0.maxY })
        case .right:
            return subtract(from: display.minY..<display.maxY, others.filter { abs($0.minX - display.maxX) < 1 }.map { $0.minY..<$0.maxY })
        }
    }

    /// The shortest open stretch worth pushing at to call the Dock back.
    static let minimumOpenStretch: CGFloat = 40

    /// Where to push to call the Dock back to the pinned display: the middle of the widest open stretch of its Dock
    /// edge, one point inside the display. Nil when no stretch is long enough (other displays cover that edge).
    static func recallPoint(displays: [CGRect], pinned: Int, orientation: DockOrientation) -> CGPoint? {
        guard displays.indices.contains(pinned) else { return nil }
        let display = displays[pinned]
        let open = openStretches(of: pinned, displays: displays, orientation: orientation)
        guard let widest = open.max(by: { $0.upperBound - $0.lowerBound < $1.upperBound - $1.lowerBound }),
              widest.upperBound - widest.lowerBound >= minimumOpenStretch else { return nil }
        let middle = (widest.lowerBound + widest.upperBound) / 2
        switch orientation {
        case .bottom: return CGPoint(x: middle, y: display.maxY - 1)
        case .left: return CGPoint(x: display.minX, y: middle)
        case .right: return CGPoint(x: display.maxX - 1, y: middle)
        }
    }

    /// The display the Dock's list is on: the one under the list's middle that is nearest it across the Dock edge. The
    /// list can sit just past a display's edge (while it slides in or out, or while hidden), so it needn't be inside.
    /// Nil when no display is within `slack` points.
    static func displayIndex(ofDockList list: CGRect, displays: [CGRect], orientation: DockOrientation, slack: CGFloat = 120) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for (index, display) in displays.enumerated() {
            let distance: CGFloat
            switch orientation {
            case .bottom:
                guard list.midX >= display.minX && list.midX < display.maxX else { continue }
                distance = list.midY < display.minY ? display.minY - list.midY : max(0, list.midY - display.maxY)
            case .left, .right:
                guard list.midY >= display.minY && list.midY < display.maxY else { continue }
                distance = list.midX < display.minX ? display.minX - list.midX : max(0, list.midX - display.maxX)
            }
            if best == nil || distance < best!.distance { best = (index, distance) }
        }
        guard let best, best.distance <= slack else { return nil }
        return best.index
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
