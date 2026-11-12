// Minimal test runner: Command Line Tools ship no XCTest, so `make test`
// compiles the pure model sources together with these files and runs them.
import Foundation

struct TestCase: Sendable {
    let name: String
    let body: @Sendable () throws -> Void
}

nonisolated(unsafe) var failureCount = 0
nonisolated(unsafe) var currentTest = ""

func expect(_ condition: Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    guard !condition else { return }
    failureCount += 1
    print("  ✗ \(currentTest) — \(message()) (\(file):\(line))")
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    guard actual != expected else { return }
    failureCount += 1
    print("  ✗ \(currentTest) — expected \(expected), got \(actual) \(message()) (\(file):\(line))")
}

func expectClose(_ actual: Double, _ expected: Double, tolerance: Double = 0.0001, file: StaticString = #filePath, line: UInt = #line) {
    guard abs(actual - expected) > tolerance else { return }
    failureCount += 1
    print("  ✗ \(currentTest) — expected \(expected) ±\(tolerance), got \(actual) (\(file):\(line))")
}

func run(_ suites: [(String, [TestCase])]) -> Never {
    var total = 0
    for (suite, tests) in suites {
        print("▸ \(suite)")
        for test in tests {
            total += 1
            currentTest = test.name
            let before = failureCount
            do { try test.body() } catch {
                failureCount += 1
                print("  ✗ \(test.name) — threw \(error)")
            }
            if failureCount == before { print("  ✓ \(test.name)") }
        }
    }
    print(failureCount == 0 ? "\n\(total) tests passed" : "\n\(failureCount) failure(s) in \(total) tests")
    exit(failureCount == 0 ? 0 : 1)
}

run([
    ("OverlayConfiguration", overlayConfigurationTests),
    ("DockGeometry", dockGeometryTests),
    ("DockSkin", dockSkinTests),
    ("WindowCornerRadius", windowCornerRadiusTests),
])
