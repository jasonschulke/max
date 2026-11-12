import AppKit
import Observation

/// The size of Apple's Dock, changed live through the private CoreDock calls System Settings uses.
/// Looked up at run time, so Max keeps working (without this control) if a macOS update removes them.
@Observable
final class DockSize {
    /// The Dock's tile size in points, or nil when the calls are unavailable.
    private(set) var tileSize: Double?

    private typealias SetTileSize = @convention(c) (Float) -> Void
    private typealias GetTileSize = @convention(c) () -> Float

    @ObservationIgnored private let setTileSize: SetTileSize?
    @ObservationIgnored private let getTileSize: GetTileSize?
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    init() {
        let services = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY)
        setTileSize = dlsym(services, "CoreDockSetTileSize").map { unsafeBitCast($0, to: SetTileSize.self) }
        getTileSize = dlsym(services, "CoreDockGetTileSize").map { unsafeBitCast($0, to: GetTileSize.self) }
        refresh()
        // The Dock posts this whenever its preferences change, including from System Settings.
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.dock.prefchanged"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        guard let getTileSize, setTileSize != nil else { return }
        let size = DockGeometry.tileSize(forFraction: Double(getTileSize())).rounded()
        if size != tileSize { tileSize = size }
    }

    func set(_ size: Double) {
        guard let setTileSize else { return }
        setTileSize(Float(DockGeometry.tileFraction(forSize: size)))
        tileSize = size
    }
}
