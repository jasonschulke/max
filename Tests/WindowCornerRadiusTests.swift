import Foundation

let windowCornerRadiusTests: [TestCase] = [
    TestCase(name: "square is stored as a radius too small to see, since AppKit ignores zero") {
        expectEqual(WindowCornerRadius.storedValue(forRadius: 0), WindowCornerRadius.square)
        expectEqual(WindowCornerRadius.storedValue(forRadius: -5), WindowCornerRadius.square)
        expectEqual(WindowCornerRadius.storedValue(forRadius: 6), 6)
        expectEqual(WindowCornerRadius.storedValue(forRadius: 40), WindowCornerRadius.systemDefault)
    },
    TestCase(name: "stored values read back as the radius windows get") {
        expectEqual(WindowCornerRadius.radius(fromStored: nil), nil)
        expectEqual(WindowCornerRadius.radius(fromStored: 0), nil)
        expectEqual(WindowCornerRadius.radius(fromStored: -1), nil)
        expectEqual(WindowCornerRadius.radius(fromStored: 0.01), 0)
        expectEqual(WindowCornerRadius.radius(fromStored: 10), 10)
    },
]
