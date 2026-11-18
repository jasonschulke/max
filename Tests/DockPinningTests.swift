import Foundation
import CoreGraphics

// CoreGraphics coordinates: the primary display at the origin, a smaller one below it, partly overlapping.
private let primary = CGRect(x: 0, y: 0, width: 1920, height: 1080)
private let below = CGRect(x: 1356, y: 1080, width: 960, height: 540)

let dockPinningTests: [TestCase] = [
    TestCase(name: "pinning to the lower display blocks the primary's bottom edge except where the lower one continues") {
        let edges = DockPinning.blockedEdges(displays: [primary, below], pinned: 1, orientation: .bottom)
        expectEqual(edges, [CGRect(x: 0, y: 1078, width: 1356, height: 2)])
    },
    TestCase(name: "pinning to the primary display blocks the whole bottom edge of the lower one") {
        let edges = DockPinning.blockedEdges(displays: [primary, below], pinned: 0, orientation: .bottom)
        expectEqual(edges, [CGRect(x: 1356, y: 1618, width: 960, height: 2)])
    },
    TestCase(name: "side-by-side displays block the outer side edges only") {
        let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        expectEqual(DockPinning.blockedEdges(displays: [primary, left], pinned: 0, orientation: .left), [CGRect(x: -1920, y: 0, width: 2, height: 1080)])
        expectEqual(DockPinning.blockedEdges(displays: [primary, left], pinned: 1, orientation: .left), [])
        expectEqual(DockPinning.blockedEdges(displays: [primary, left], pinned: 1, orientation: .right), [CGRect(x: 1918, y: 0, width: 2, height: 1080)])
    },
    TestCase(name: "the pointer is held just short of a blocked edge") {
        let edges = [CGRect(x: 0, y: 1078, width: 1356, height: 2)]
        expectEqual(DockPinning.clamped(CGPoint(x: 600, y: 1079), edges: edges, orientation: .bottom), CGPoint(x: 600, y: 1077.5))
        expectEqual(DockPinning.clamped(CGPoint(x: 600, y: 1000), edges: edges, orientation: .bottom), nil)
        expectEqual(DockPinning.clamped(CGPoint(x: 1500, y: 1079), edges: edges, orientation: .bottom), nil)
        let side = [CGRect(x: -1920, y: 0, width: 2, height: 1080)]
        expectEqual(DockPinning.clamped(CGPoint(x: -1920, y: 50), edges: side, orientation: .left), CGPoint(x: -1917.5, y: 50))
    },
    TestCase(name: "the recall push goes to the widest open stretch of the pinned display's edge") {
        // The LG on top, a tablet and a small display below it, as on Jason's desk.
        let tablet = CGRect(x: 76, y: 1080, width: 1024, height: 640)
        expectEqual(DockPinning.recallPoint(displays: [primary, tablet, below], pinned: 0, orientation: .bottom), CGPoint(x: 1228, y: 1079))
        expectEqual(DockPinning.recallPoint(displays: [primary, below], pinned: 1, orientation: .bottom), CGPoint(x: 1836, y: 1619))
        let covering = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
        expectEqual(DockPinning.recallPoint(displays: [primary, covering], pinned: 0, orientation: .bottom), nil)
    },
    TestCase(name: "the Dock's list belongs to the display it sits at, even just past its edge") {
        let tablet = CGRect(x: 76, y: 1080, width: 1024, height: 640)
        let displays = [primary, tablet, below]
        expectEqual(DockPinning.displayIndex(ofDockList: CGRect(x: 1359, y: 1620, width: 954, height: 27), displays: displays, orientation: .bottom), 2)
        expectEqual(DockPinning.displayIndex(ofDockList: CGRect(x: 300, y: 1020, width: 1300, height: 56), displays: displays, orientation: .bottom), 0)
        expectEqual(DockPinning.displayIndex(ofDockList: CGRect(x: 300, y: 3000, width: 100, height: 56), displays: displays, orientation: .bottom), nil)
    },
    TestCase(name: "range subtraction keeps the uncovered stretches") {
        expectEqual(DockPinning.subtract(from: 0..<10, [3..<5]), [0..<3, 5..<10])
        expectEqual(DockPinning.subtract(from: 0..<10, [-5..<20]), [])
        expectEqual(DockPinning.subtract(from: 0..<10, [12..<20]), [0..<10])
    },
]
