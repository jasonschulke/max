import Cocoa
import Combine

// MARK: - NSColor Extension

extension NSColor {
    func isEqual(to color: NSColor) -> Bool {
        guard let c1 = self.usingColorSpace(.deviceRGB),
              let c2 = color.usingColorSpace(.deviceRGB) else {
            return false
        }
        return c1.redComponent == c2.redComponent &&
               c1.greenComponent == c2.greenComponent &&
               c1.blueComponent == c2.blueComponent &&
               c1.alphaComponent == c2.alphaComponent
    }
}

// MARK: - Overlay Window Controller

class OverlayWindowController {
    private var window: NSWindow!
    private var containerView: NSView!
    private var backgroundView: NSView!
    private var effectView: NSVisualEffectView!
    private var gradientLayer: CAGradientLayer?

    private var configService: ConfigurationService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(configService: ConfigurationService) {
        self.configService = configService
        setupWindow()
        setupViews()
        setupScreenChangeObserver()
        setupConfigurationObservers()
    }

    // MARK: - Window Setup

    private func setupWindow() {
        guard let screen = NSScreen.main else { return }
        let fullFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        let overlayHeight = configService.configuration.height
        let dockHeight = visibleFrame.minY - fullFrame.minY
        let totalHeight = max(overlayHeight, dockHeight)

        window = NSWindow(
            contentRect: NSRect(
                x: fullFrame.minX,
                y: fullFrame.minY,
                width: fullFrame.width,
                height: totalHeight
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = false
    }

    // MARK: - View Setup

    private func setupViews() {
        guard let contentView = window.contentView else { return }

        let config = configService.configuration

        // Create container view
        containerView = NSView(frame: contentView.bounds)
        containerView.wantsLayer = true
        containerView.autoresizingMask = [.width, .height]

        // Create background view
        backgroundView = createBackgroundView(frame: containerView.bounds)
        containerView.addSubview(backgroundView)

        // Create visual effect view
        effectView = NSVisualEffectView(frame: containerView.bounds)
        effectView.material = config.material
        effectView.blendingMode = config.blendingMode
        effectView.state = .active
        effectView.autoresizingMask = [.width, .height]
        effectView.alphaValue = config.opacity

        containerView.addSubview(effectView)
        window.contentView = containerView
    }

    private func createBackgroundView(frame: NSRect) -> NSView {
        let view = NSView(frame: frame)
        view.wantsLayer = true
        view.autoresizingMask = [.width, .height]

        let config = configService.configuration

        if config.useCustomColor {
            if config.useGradient {
                // Create gradient layer
                let gradient = GradientLayerFactory.createGradientLayer(
                    color: config.customColor,
                    opacity: config.backgroundOpacity,
                    frame: frame
                )
                view.layer?.addSublayer(gradient)
                gradientLayer = gradient
            } else {
                // Solid custom color
                view.layer?.backgroundColor = config.customColor
                    .withAlphaComponent(config.backgroundOpacity)
                    .cgColor
            }
        } else {
            // Default system color
            view.layer?.backgroundColor = NSColor.windowBackgroundColor
                .withAlphaComponent(config.backgroundOpacity)
                .cgColor
        }

        return view
    }

    // MARK: - Screen Change Observer

    private func setupScreenChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc func handleScreenChange() {
        updateFrame()
    }

    // MARK: - Configuration Observers

    private func setupConfigurationObservers() {
        // Observe height changes
        configService.$configuration
            .map { $0.height }
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateFrame()
            }
            .store(in: &cancellables)

        // Observe opacity changes
        configService.$configuration
            .map { $0.opacity }
            .removeDuplicates()
            .sink { [weak self] opacity in
                self?.updateOpacity(opacity)
            }
            .store(in: &cancellables)

        // Observe material changes
        configService.$configuration
            .map { $0.material }
            .removeDuplicates()
            .sink { [weak self] material in
                self?.effectView.material = material
            }
            .store(in: &cancellables)

        // Observe blending mode changes
        configService.$configuration
            .map { $0.blendingMode }
            .removeDuplicates()
            .sink { [weak self] blendingMode in
                self?.effectView.blendingMode = blendingMode
            }
            .store(in: &cancellables)

        // Observe background changes (color, gradient, opacity)
        configService.$configuration
            .map { ($0.useCustomColor, $0.customColor, $0.useGradient, $0.backgroundOpacity) }
            .removeDuplicates { (old: (Bool, NSColor, Bool, Double), new: (Bool, NSColor, Bool, Double)) -> Bool in
                let colorsEqual = old.1.isEqual(to: new.1)
                return old.0 == new.0 && colorsEqual && old.2 == new.2 && old.3 == new.3
            }
            .sink { [weak self] _ in
                self?.updateBackgroundAppearance()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func show(animated: Bool) {
        let animationsEnabled = configService.configuration.animationsEnabled
        if animated && animationsEnabled {
            window.alphaValue = 0
            window.orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                window.animator().alphaValue = 1
            }
        } else {
            window.orderFront(nil)
        }
    }

    func hide(animated: Bool) {
        let animationsEnabled = configService.configuration.animationsEnabled
        if animated && animationsEnabled {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                window.animator().alphaValue = 0
            }, completionHandler: {
                self.window.orderOut(nil)
                self.window.alphaValue = 1
            })
        } else {
            window.orderOut(nil)
        }
    }

    private func updateOpacity(_ opacity: Double) {
        let animationsEnabled = configService.configuration.animationsEnabled
        if animationsEnabled {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                effectView.animator().alphaValue = opacity
            }
        } else {
            effectView.alphaValue = opacity
        }
    }

    private func updateBackgroundAppearance() {
        let config = configService.configuration

        // Remove old sublayers
        backgroundView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        gradientLayer = nil

        if config.useCustomColor {
            if config.useGradient {
                // Create new gradient layer
                let gradient = GradientLayerFactory.createGradientLayer(
                    color: config.customColor,
                    opacity: config.backgroundOpacity,
                    frame: backgroundView.bounds
                )
                backgroundView.layer?.addSublayer(gradient)
                gradientLayer = gradient
            } else {
                // Solid custom color
                backgroundView.layer?.backgroundColor = config.customColor
                    .withAlphaComponent(config.backgroundOpacity)
                    .cgColor
            }
        } else {
            // Default system color
            backgroundView.layer?.backgroundColor = NSColor.windowBackgroundColor
                .withAlphaComponent(config.backgroundOpacity)
                .cgColor
        }
    }

    // MARK: - Private Methods

    private func updateFrame() {
        guard let screen = NSScreen.main else { return }
        let fullFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let config = configService.configuration
        let newHeight = config.height
        let dockHeight = visibleFrame.minY - fullFrame.minY
        let totalHeight = max(newHeight, dockHeight)

        window.setFrame(
            NSRect(
                x: fullFrame.minX,
                y: fullFrame.minY,
                width: fullFrame.width,
                height: totalHeight
            ),
            display: true,
            animate: config.animationsEnabled
        )
    }

    // MARK: - Deinitialization

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
