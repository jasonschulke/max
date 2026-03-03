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
        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 500
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        window = NSWindow(
            contentRect: NSRect(
                x: visibleFrame.midX - windowWidth / 2,
                y: visibleFrame.midY - windowHeight / 2,
                width: windowWidth,
                height: windowHeight
            ),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Max Settings"
        window.isReleasedWhenClosed = false
    }

    // MARK: - UI Setup

    private func setupUI() {
        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 500

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        contentView.autoresizingMask = [.width, .height]

        let config = configService.configuration
        let columnWidth: CGFloat = (windowWidth - 60) / 2  // 20 padding on each side, 20 gap in middle
        let leftX: CGFloat = 20
        let rightX: CGFloat = leftX + columnWidth + 20

        var leftY: CGFloat = windowHeight - 40
        var rightY: CGFloat = windowHeight - 40

        // MARK: Enable/Disable Section (spans both columns)
        enabledCheckbox = NSButton(checkboxWithTitle: "Enable Overlay", target: self, action: #selector(enabledChanged))
        enabledCheckbox.state = config.isEnabled ? .on : .off
        enabledCheckbox.frame = NSRect(x: leftX, y: leftY, width: windowWidth - 40, height: 20)
        contentView.addSubview(enabledCheckbox)
        leftY -= 40
        rightY -= 40

        // LEFT COLUMN

        // MARK: Height Section
        let heightTitleLabel = NSTextField(labelWithString: "Overlay Height")
        heightTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        heightTitleLabel.frame = NSRect(x: leftX, y: leftY, width: 150, height: 20)
        contentView.addSubview(heightTitleLabel)
        leftY -= 30

        heightSlider = NSSlider(value: Double(config.height), minValue: 20, maxValue: 300, target: self, action: #selector(heightSliderChanged))
        heightSlider.isContinuous = true
        heightSlider.frame = NSRect(x: leftX, y: leftY, width: columnWidth - 90, height: 24)
        contentView.addSubview(heightSlider)

        heightLabel = NSTextField(labelWithString: "\(Int(config.height)) px")
        heightLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        heightLabel.frame = NSRect(x: leftX + columnWidth - 80, y: leftY, width: 70, height: 24)
        heightLabel.alignment = .right
        contentView.addSubview(heightLabel)
        leftY -= 45

        // MARK: Effect Opacity Section
        let opacityTitleLabel = NSTextField(labelWithString: "Effect Opacity")
        opacityTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        opacityTitleLabel.frame = NSRect(x: leftX, y: leftY, width: 150, height: 20)
        contentView.addSubview(opacityTitleLabel)
        leftY -= 30

        opacitySlider = NSSlider(value: config.opacity, minValue: 0.1, maxValue: 1.0, target: self, action: #selector(opacitySliderChanged))
        opacitySlider.isContinuous = true
        opacitySlider.frame = NSRect(x: leftX, y: leftY, width: columnWidth - 90, height: 24)
        contentView.addSubview(opacitySlider)

        opacityLabel = NSTextField(labelWithString: "\(Int(config.opacity * 100))%")
        opacityLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        opacityLabel.frame = NSRect(x: leftX + columnWidth - 80, y: leftY, width: 70, height: 24)
        opacityLabel.alignment = .right
        contentView.addSubview(opacityLabel)
        leftY -= 45

        // MARK: Background Opacity Section
        let bgOpacityTitleLabel = NSTextField(labelWithString: "Background Opacity")
        bgOpacityTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        bgOpacityTitleLabel.frame = NSRect(x: leftX, y: leftY, width: 180, height: 20)
        contentView.addSubview(bgOpacityTitleLabel)
        leftY -= 30

        backgroundOpacitySlider = NSSlider(value: config.backgroundOpacity, minValue: 0.0, maxValue: 1.0, target: self, action: #selector(backgroundOpacitySliderChanged))
        backgroundOpacitySlider.isContinuous = true
        backgroundOpacitySlider.frame = NSRect(x: leftX, y: leftY, width: columnWidth - 90, height: 24)
        contentView.addSubview(backgroundOpacitySlider)

        backgroundOpacityLabel = NSTextField(labelWithString: "\(Int(config.backgroundOpacity * 100))%")
        backgroundOpacityLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        backgroundOpacityLabel.frame = NSRect(x: leftX + columnWidth - 80, y: leftY, width: 70, height: 24)
        backgroundOpacityLabel.alignment = .right
        contentView.addSubview(backgroundOpacityLabel)
        leftY -= 50

        // MARK: Custom Color Section
        useCustomColorCheckbox = NSButton(checkboxWithTitle: "Use Custom Background Color", target: self, action: #selector(customColorToggled))
        useCustomColorCheckbox.state = config.useCustomColor ? .on : .off
        useCustomColorCheckbox.frame = NSRect(x: leftX, y: leftY, width: columnWidth, height: 20)
        contentView.addSubview(useCustomColorCheckbox)
        leftY -= 35

        colorWell = NSColorWell(frame: NSRect(x: leftX + 20, y: leftY, width: 60, height: 30))
        colorWell.color = config.customColor
        colorWell.target = self
        colorWell.action = #selector(colorChanged)
        colorWell.isEnabled = config.useCustomColor
        contentView.addSubview(colorWell)

        gradientCheckbox = NSButton(checkboxWithTitle: "Use Gradient", target: self, action: #selector(gradientToggled))
        gradientCheckbox.state = config.useGradient ? .on : .off
        gradientCheckbox.frame = NSRect(x: leftX + 90, y: leftY + 5, width: 150, height: 20)
        gradientCheckbox.isEnabled = config.useCustomColor
        contentView.addSubview(gradientCheckbox)

        // RIGHT COLUMN

        // MARK: Material Section
        let materialTitleLabel = NSTextField(labelWithString: "Material")
        materialTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        materialTitleLabel.frame = NSRect(x: rightX, y: rightY, width: 150, height: 20)
        contentView.addSubview(materialTitleLabel)
        rightY -= 30

        materialPopup = NSPopUpButton(frame: NSRect(x: rightX, y: rightY, width: columnWidth, height: 26), pullsDown: false)
        materialPopup.removeAllItems()
        materialPopup.addItems(withTitles: OverlayConfiguration.materials.map { $0.name })
        materialPopup.selectItem(at: config.materialIndex)
        materialPopup.target = self
        materialPopup.action = #selector(materialChanged)
        contentView.addSubview(materialPopup)
        rightY -= 45

        // MARK: Blending Mode Section
        let blendingTitleLabel = NSTextField(labelWithString: "Blending Mode")
        blendingTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        blendingTitleLabel.frame = NSRect(x: rightX, y: rightY, width: 150, height: 20)
        contentView.addSubview(blendingTitleLabel)
        rightY -= 30

        blendingPopup = NSPopUpButton(frame: NSRect(x: rightX, y: rightY, width: columnWidth, height: 26), pullsDown: false)
        blendingPopup.removeAllItems()
        blendingPopup.addItems(withTitles: OverlayConfiguration.blendingModes.map { $0.name })
        blendingPopup.selectItem(at: config.blendingModeIndex)
        blendingPopup.target = self
        blendingPopup.action = #selector(blendingModeChanged)
        contentView.addSubview(blendingPopup)
        rightY -= 50

        // MARK: Animations Section
        animationsCheckbox = NSButton(checkboxWithTitle: "Enable Smooth Animations", target: self, action: #selector(animationsToggled))
        animationsCheckbox.state = config.animationsEnabled ? .on : .off
        animationsCheckbox.frame = NSRect(x: rightX, y: rightY, width: columnWidth, height: 20)
        contentView.addSubview(animationsCheckbox)
        rightY -= 35

        // MARK: Launch at Login Section
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: self, action: #selector(launchAtLoginToggled))
        launchAtLoginCheckbox.state = config.launchAtLogin ? .on : .off
        launchAtLoginCheckbox.frame = NSRect(x: rightX, y: rightY, width: columnWidth, height: 20)
        contentView.addSubview(launchAtLoginCheckbox)
        rightY -= 50

        // MARK: Buttons
        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetToDefaults))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(x: rightX, y: rightY, width: 160, height: 32)
        contentView.addSubview(resetButton)

        // MARK: Info Section (bottom, spans both columns)
        let bottomY = min(leftY, rightY) - 30
        let infoLabel = NSTextField(wrappingLabelWithString: "Tip: Try 'Under Window Background' material with high background opacity (85%+) and high effect opacity (90%+) for best dock coverage. Use Cmd+T to toggle.")
        infoLabel.font = .systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.frame = NSRect(x: leftX, y: bottomY - 45, width: windowWidth - 40, height: 45)
        contentView.addSubview(infoLabel)

        window.contentView = contentView
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
