import Cocoa
import Combine

// MARK: - Delegate Protocol

protocol SettingsWindowDelegate: AnyObject {
    func settingsLaunchAtLoginToggled(_ enabled: Bool)
}

// MARK: - Settings Window Controller

class SettingsWindowController {
    private var window: NSWindow!
    private weak var delegate: SettingsWindowDelegate?

    // UI Controls
    private var enabledCheckbox: NSButton!
    private var heightSlider: NSSlider!
    private var heightLabel: NSTextField!
    private var opacitySlider: NSSlider!
    private var opacityLabel: NSTextField!
    private var backgroundOpacitySlider: NSSlider!
    private var backgroundOpacityLabel: NSTextField!
    private var materialPopup: NSPopUpButton!
    private var blendingPopup: NSPopUpButton!
    private var useCustomColorCheckbox: NSButton!
    private var colorWell: NSColorWell!
    private var gradientCheckbox: NSButton!
    private var animationsCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!

    private var configService: ConfigurationService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(configService: ConfigurationService) {
        self.configService = configService
        setupWindow()
        setupUI()
        setupConfigurationObservers()

        // Set delegate after initialization
        if let appDelegate = NSApp.delegate as? SettingsWindowDelegate {
            self.delegate = appDelegate
        }
    }

    // MARK: - Window Setup

    private func setupWindow() {
        let windowWidth: CGFloat = 450
        let windowHeight: CGFloat = 700

        // Get screen or use default positioning
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        window = NSWindow(
            contentRect: NSRect(
                x: visibleFrame.midX - windowWidth / 2,
                y: visibleFrame.midY - windowHeight / 2,
                width: windowWidth,
                height: windowHeight
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Max Settings"
        window.isReleasedWhenClosed = false
    }

    // MARK: - UI Setup

    private func setupUI() {
        let windowWidth: CGFloat = 450
        let windowHeight: CGFloat = 700

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .noBorder

        let contentWidth = windowWidth - 20
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 1000))

        var currentY: CGFloat = 960

        // MARK: Enable/Disable Section
        let config = configService.configuration
        enabledCheckbox = NSButton(checkboxWithTitle: "Enable Overlay", target: self, action: #selector(enabledChanged))
        enabledCheckbox.state = config.isEnabled ? .on : .off
        enabledCheckbox.frame = NSRect(x: 20, y: currentY, width: contentWidth - 40, height: 20)
        contentView.addSubview(enabledCheckbox)
        currentY -= 40

        addSeparator(to: contentView, y: currentY, width: contentWidth)
        currentY -= 25

        // MARK: Height Section
        let heightTitleLabel = NSTextField(labelWithString: "Overlay Height")
        heightTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        heightTitleLabel.frame = NSRect(x: 20, y: currentY, width: 150, height: 20)
        contentView.addSubview(heightTitleLabel)
        currentY -= 30

        heightSlider = NSSlider(value: Double(config.height), minValue: 20, maxValue: 300, target: self, action: #selector(heightSliderChanged))
        heightSlider.isContinuous = true
        heightSlider.frame = NSRect(x: 20, y: currentY, width: contentWidth - 160, height: 24)
        contentView.addSubview(heightSlider)

        heightLabel = NSTextField(labelWithString: "\(Int(config.height)) px")
        heightLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        heightLabel.frame = NSRect(x: contentWidth - 130, y: currentY, width: 110, height: 24)
        heightLabel.alignment = .right
        contentView.addSubview(heightLabel)
        currentY -= 45

        // MARK: Effect Opacity Section
        let opacityTitleLabel = NSTextField(labelWithString: "Effect Opacity")
        opacityTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        opacityTitleLabel.frame = NSRect(x: 20, y: currentY, width: 150, height: 20)
        contentView.addSubview(opacityTitleLabel)
        currentY -= 30

        opacitySlider = NSSlider(value: config.opacity, minValue: 0.1, maxValue: 1.0, target: self, action: #selector(opacitySliderChanged))
        opacitySlider.isContinuous = true
        opacitySlider.frame = NSRect(x: 20, y: currentY, width: contentWidth - 160, height: 24)
        contentView.addSubview(opacitySlider)

        opacityLabel = NSTextField(labelWithString: "\(Int(config.opacity * 100))%")
        opacityLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        opacityLabel.frame = NSRect(x: contentWidth - 130, y: currentY, width: 110, height: 24)
        opacityLabel.alignment = .right
        contentView.addSubview(opacityLabel)
        currentY -= 45

        // MARK: Background Opacity Section
        let bgOpacityTitleLabel = NSTextField(labelWithString: "Background Opacity")
        bgOpacityTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        bgOpacityTitleLabel.frame = NSRect(x: 20, y: currentY, width: 180, height: 20)
        contentView.addSubview(bgOpacityTitleLabel)
        currentY -= 30

        backgroundOpacitySlider = NSSlider(value: config.backgroundOpacity, minValue: 0.0, maxValue: 1.0, target: self, action: #selector(backgroundOpacitySliderChanged))
        backgroundOpacitySlider.isContinuous = true
        backgroundOpacitySlider.frame = NSRect(x: 20, y: currentY, width: contentWidth - 160, height: 24)
        contentView.addSubview(backgroundOpacitySlider)

        backgroundOpacityLabel = NSTextField(labelWithString: "\(Int(config.backgroundOpacity * 100))%")
        backgroundOpacityLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        backgroundOpacityLabel.frame = NSRect(x: contentWidth - 130, y: currentY, width: 110, height: 24)
        backgroundOpacityLabel.alignment = .right
        contentView.addSubview(backgroundOpacityLabel)
        currentY -= 50

        addSeparator(to: contentView, y: currentY, width: contentWidth)
        currentY -= 25

        // MARK: Custom Color Section
        useCustomColorCheckbox = NSButton(checkboxWithTitle: "Use Custom Background Color", target: self, action: #selector(customColorToggled))
        useCustomColorCheckbox.state = config.useCustomColor ? .on : .off
        useCustomColorCheckbox.frame = NSRect(x: 20, y: currentY, width: contentWidth - 40, height: 20)
        contentView.addSubview(useCustomColorCheckbox)
        currentY -= 40

        colorWell = NSColorWell(frame: NSRect(x: 40, y: currentY, width: 60, height: 30))
        colorWell.color = config.customColor
        colorWell.target = self
        colorWell.action = #selector(colorChanged)
        colorWell.isEnabled = config.useCustomColor
        contentView.addSubview(colorWell)

        gradientCheckbox = NSButton(checkboxWithTitle: "Use Gradient", target: self, action: #selector(gradientToggled))
        gradientCheckbox.state = config.useGradient ? .on : .off
        gradientCheckbox.frame = NSRect(x: 110, y: currentY + 5, width: 150, height: 20)
        gradientCheckbox.isEnabled = config.useCustomColor
        contentView.addSubview(gradientCheckbox)
        currentY -= 50

        addSeparator(to: contentView, y: currentY, width: contentWidth)
        currentY -= 25

        // MARK: Material Section
        let materialTitleLabel = NSTextField(labelWithString: "Material")
        materialTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        materialTitleLabel.frame = NSRect(x: 20, y: currentY, width: 150, height: 20)
        contentView.addSubview(materialTitleLabel)
        currentY -= 30

        materialPopup = NSPopUpButton(frame: NSRect(x: 20, y: currentY, width: contentWidth - 40, height: 26), pullsDown: false)
        materialPopup.removeAllItems()
        materialPopup.addItems(withTitles: OverlayConfiguration.materials.map { $0.name })
        materialPopup.selectItem(at: config.materialIndex)
        materialPopup.target = self
        materialPopup.action = #selector(materialChanged)
        contentView.addSubview(materialPopup)
        currentY -= 45

        // MARK: Blending Mode Section
        let blendingTitleLabel = NSTextField(labelWithString: "Blending Mode")
        blendingTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        blendingTitleLabel.frame = NSRect(x: 20, y: currentY, width: 150, height: 20)
        contentView.addSubview(blendingTitleLabel)
        currentY -= 30

        blendingPopup = NSPopUpButton(frame: NSRect(x: 20, y: currentY, width: contentWidth - 40, height: 26), pullsDown: false)
        blendingPopup.removeAllItems()
        blendingPopup.addItems(withTitles: OverlayConfiguration.blendingModes.map { $0.name })
        blendingPopup.selectItem(at: config.blendingModeIndex)
        blendingPopup.target = self
        blendingPopup.action = #selector(blendingModeChanged)
        contentView.addSubview(blendingPopup)
        currentY -= 50

        addSeparator(to: contentView, y: currentY, width: contentWidth)
        currentY -= 25

        // MARK: Animations Section
        animationsCheckbox = NSButton(checkboxWithTitle: "Enable Smooth Animations", target: self, action: #selector(animationsToggled))
        animationsCheckbox.state = config.animationsEnabled ? .on : .off
        animationsCheckbox.frame = NSRect(x: 20, y: currentY, width: contentWidth - 40, height: 20)
        contentView.addSubview(animationsCheckbox)
        currentY -= 45

        addSeparator(to: contentView, y: currentY, width: contentWidth)
        currentY -= 25

        // MARK: Launch at Login Section
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: self, action: #selector(launchAtLoginToggled))
        launchAtLoginCheckbox.state = config.launchAtLogin ? .on : .off
        launchAtLoginCheckbox.frame = NSRect(x: 20, y: currentY, width: contentWidth - 40, height: 20)
        contentView.addSubview(launchAtLoginCheckbox)
        currentY -= 50

        addSeparator(to: contentView, y: currentY, width: contentWidth)
        currentY -= 25

        // MARK: Info Section
        let infoLabel = NSTextField(wrappingLabelWithString: "Tip: Try 'Under Window Background' material with high background opacity (85%+) and high effect opacity (90%+) for best dock coverage. Use Cmd+T to toggle.")
        infoLabel.font = .systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.frame = NSRect(x: 20, y: currentY - 60, width: contentWidth - 40, height: 70)
        contentView.addSubview(infoLabel)
        currentY -= 85

        // MARK: Buttons
        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetToDefaults))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(x: 20, y: currentY, width: 160, height: 32)
        contentView.addSubview(resetButton)
        currentY -= 50

        // Update content view frame
        contentView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: 1000 - currentY)

        scrollView.documentView = contentView
        window.contentView = scrollView
    }

    private func addSeparator(to view: NSView, y: CGFloat, width: CGFloat) {
        let separator = NSBox(frame: NSRect(x: 20, y: y, width: width - 40, height: 1))
        separator.boxType = .separator
        view.addSubview(separator)
    }

    // MARK: - Configuration Observers

    private func setupConfigurationObservers() {
        // Observe all configuration changes and update UI controls
        configService.$configuration
            .sink { [weak self] config in
                self?.updateUIControls(with: config)
            }
            .store(in: &cancellables)
    }

    private func updateUIControls(with config: OverlayConfiguration) {
        enabledCheckbox.state = config.isEnabled ? .on : .off
        heightSlider.doubleValue = Double(config.height)
        heightLabel.stringValue = "\(Int(config.height)) px"
        opacitySlider.doubleValue = config.opacity
        opacityLabel.stringValue = "\(Int(config.opacity * 100))%"
        backgroundOpacitySlider.doubleValue = config.backgroundOpacity
        backgroundOpacityLabel.stringValue = "\(Int(config.backgroundOpacity * 100))%"
        materialPopup.selectItem(at: config.materialIndex)
        blendingPopup.selectItem(at: config.blendingModeIndex)
        useCustomColorCheckbox.state = config.useCustomColor ? .on : .off
        colorWell.color = config.customColor
        colorWell.isEnabled = config.useCustomColor
        gradientCheckbox.state = config.useGradient ? .on : .off
        gradientCheckbox.isEnabled = config.useCustomColor
        animationsCheckbox.state = config.animationsEnabled ? .on : .off
        launchAtLoginCheckbox.state = config.launchAtLogin ? .on : .off
    }

    // MARK: - Event Handlers

    @objc private func enabledChanged(_ sender: NSButton) {
        configService.updateEnabled(sender.state == .on)
    }

    @objc private func heightSliderChanged(_ sender: NSSlider) {
        let newHeight = CGFloat(sender.doubleValue)
        heightLabel.stringValue = "\(Int(newHeight)) px"
        configService.updateHeight(newHeight)
    }

    @objc private func opacitySliderChanged(_ sender: NSSlider) {
        let newOpacity = sender.doubleValue
        opacityLabel.stringValue = "\(Int(newOpacity * 100))%"
        configService.updateOpacity(newOpacity)
    }

    @objc private func backgroundOpacitySliderChanged(_ sender: NSSlider) {
        let newOpacity = sender.doubleValue
        backgroundOpacityLabel.stringValue = "\(Int(newOpacity * 100))%"
        configService.updateBackgroundOpacity(newOpacity)
    }

    @objc private func materialChanged(_ sender: NSPopUpButton) {
        configService.updateMaterial(sender.indexOfSelectedItem)
    }

    @objc private func blendingModeChanged(_ sender: NSPopUpButton) {
        configService.updateBlendingMode(sender.indexOfSelectedItem)
    }

    @objc private func customColorToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        colorWell.isEnabled = enabled
        gradientCheckbox.isEnabled = enabled
        configService.updateCustomColorEnabled(enabled)
    }

    @objc private func colorChanged(_ sender: NSColorWell) {
        configService.updateCustomColor(sender.color)
    }

    @objc private func gradientToggled(_ sender: NSButton) {
        configService.updateGradientEnabled(sender.state == .on)
    }

    @objc private func animationsToggled(_ sender: NSButton) {
        configService.updateAnimationsEnabled(sender.state == .on)
    }

    @objc private func launchAtLoginToggled(_ sender: NSButton) {
        delegate?.settingsLaunchAtLoginToggled(sender.state == .on)
    }

    @objc private func resetToDefaults() {
        configService.resetToDefaults()
    }

    // MARK: - Public Methods

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
