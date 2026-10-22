import Cocoa
import Combine

class ConfigurationService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var configuration: OverlayConfiguration

    // MARK: - Dependencies

    private let persistenceManager: PersistenceManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(persistenceManager: PersistenceManager = PersistenceManager()) {
        self.persistenceManager = persistenceManager
        self.configuration = persistenceManager.loadConfiguration()

        // Auto-save configuration changes
        setupAutoSave()
    }

    // MARK: - Auto-Save Setup

    private func setupAutoSave() {
        $configuration
            .dropFirst() // Skip initial value
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] config in
                self?.persistConfiguration(config)
            }
            .store(in: &cancellables)
    }

    private func persistConfiguration(_ config: OverlayConfiguration) {
        persistenceManager.saveHeight(config.height)
        persistenceManager.saveOpacity(config.opacity)
        persistenceManager.saveBackgroundOpacity(config.backgroundOpacity)
        persistenceManager.saveMaterialIndex(config.materialIndex)
        persistenceManager.saveBlendingModeIndex(config.blendingModeIndex)
        persistenceManager.saveEnabled(config.isEnabled)
        persistenceManager.saveUseCustomColor(config.useCustomColor)
        persistenceManager.saveColor(config.customColor)
        persistenceManager.saveUseGradient(config.useGradient)
        persistenceManager.saveAnimationsEnabled(config.animationsEnabled)
        persistenceManager.saveLaunchAtLogin(config.launchAtLogin)
    }

    // MARK: - Public Update Methods

    func updateEnabled(_ enabled: Bool) {
        configuration.isEnabled = enabled
    }

    func updateHeight(_ height: CGFloat) {
        configuration.height = height
    }

    func updateOpacity(_ opacity: Double) {
        configuration.opacity = opacity
    }

    func updateBackgroundOpacity(_ opacity: Double) {
        configuration.backgroundOpacity = opacity
    }

    func updateMaterial(_ index: Int) {
        configuration.materialIndex = index
    }

    func updateBlendingMode(_ index: Int) {
        configuration.blendingModeIndex = index
    }

    func updateCustomColorEnabled(_ enabled: Bool) {
        configuration.useCustomColor = enabled
    }

    func updateCustomColor(_ color: NSColor) {
        configuration.customColor = color
    }

    func updateGradientEnabled(_ enabled: Bool) {
        configuration.useGradient = enabled
    }

    func updateAnimationsEnabled(_ enabled: Bool) {
        configuration.animationsEnabled = enabled
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        configuration.launchAtLogin = enabled
    }

    func resetToDefaults() {
        configuration = OverlayConfiguration()
        persistenceManager.resetToDefaults()
    }
}
