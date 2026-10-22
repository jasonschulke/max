import SwiftUI

struct SettingsView: View {
    @Bindable var store: SettingsStore
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginItemMessage: String?

    private var config: Binding<OverlayConfiguration> { $store.configuration }

    var body: some View {
        Form {
            Section {
                Toggle("Show Dock bar", isOn: config.isEnabled)
                Toggle("Launch at login", isOn: $launchAtLogin)
            }

            Section("Appearance") {
                Picker("Style", selection: config.style) {
                    ForEach(OverlayConfiguration.Style.allCases) { Text($0.title).tag($0) }
                }
                if store.configuration.style == .blur {
                    Picker("Material", selection: config.blurMaterial) {
                        ForEach(OverlayConfiguration.BlurMaterial.allCases) { Text($0.title).tag($0) }
                    }
                }
                SettingSlider("Opacity", value: config.opacity, in: OverlayConfiguration.opacityRange,
                              label: percent, onEditingChanged: setInteracting)
                SettingSlider("Corner radius", value: config.cornerRadius, in: OverlayConfiguration.cornerRadiusRange,
                              label: points, onEditingChanged: setInteracting)
            }

            Section {
                Picker("Height", selection: config.heightMode) {
                    ForEach(OverlayConfiguration.HeightMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if store.configuration.heightMode == .matchDock {
                    SettingSlider("Adjustment", value: config.heightAdjustment, in: OverlayConfiguration.heightAdjustmentRange,
                                  label: signedPoints, onEditingChanged: setInteracting)
                } else {
                    SettingSlider("Height", value: config.customHeight, in: OverlayConfiguration.customHeightRange,
                                  label: points, onEditingChanged: setInteracting)
                }
            } header: {
                Text("Size")
            } footer: {
                Text("Match Dock sizes the bar to the strip macOS reserves for the Dock, and follows the Dock when it is resized.")
            }

            Section("Tint") {
                Toggle("Tint the bar", isOn: config.tint.isEnabled)
                Group {
                    ColorPicker("Color", selection: tintColor, supportsOpacity: false)
                    SettingSlider("Strength", value: config.tint.strength, in: OverlayConfiguration.tintStrengthRange,
                                  label: percent, onEditingChanged: setInteracting)
                    Toggle("Fade toward the screen", isOn: config.tint.fadesUpward)
                }
                .disabled(!store.configuration.tint.isEnabled)
            }

            Section("Behavior") {
                Toggle("Animate changes", isOn: config.animationsEnabled)
                Toggle("Follow the Dock when it auto-hides", isOn: config.mirrorsDockAutoHide)
                Toggle("Toggle the bar with \(GlobalHotKey.Shortcut.toggleOverlay.display) anywhere", isOn: config.globalShortcutEnabled)
            }

            Section {
                Button("Reset to Defaults") { store.resetToDefaults() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
        .onChange(of: launchAtLogin) { _, enabled in updateLaunchAtLogin(enabled) }
        .alert("Launch at Login", isPresented: Binding(
            get: { loginItemMessage != nil },
            set: { if !$0 { loginItemMessage = nil } }
        )) {
            Button("Open Login Items") { LaunchAtLogin.openSystemSettings() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginItemMessage ?? "")
        }
    }

    private var tintColor: Binding<Color> {
        Binding(
            get: { store.configuration.tint.color.swiftUIColor },
            set: { newColor in
                if let color = RGBAColor(newColor) { store.configuration.tint.color = color }
            }
        )
    }

    private func setInteracting(_ interacting: Bool) {
        store.isInteracting = interacting
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        guard enabled != LaunchAtLogin.isEnabled else { return }
        do {
            try LaunchAtLogin.setEnabled(enabled)
            if enabled, LaunchAtLogin.requiresApproval {
                loginItemMessage = "macOS needs you to approve Max under System Settings › General › Login Items."
            }
        } catch {
            launchAtLogin = LaunchAtLogin.isEnabled
            loginItemMessage = "Could not \(enabled ? "enable" : "disable") launch at login.\n\n\(error.localizedDescription)"
        }
    }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
    private func points(_ value: Double) -> String { "\(Int(value.rounded())) pt" }
    private func signedPoints(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded > 0 ? "+\(rounded) pt" : "\(rounded) pt"
    }
}

/// A labeled slider with a live read-out. Reports drag start and end so the overlay can skip animation while tracking.
private struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: (Double) -> String
    let onEditingChanged: (Bool) -> Void

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>,
         label: @escaping (Double) -> String, onEditingChanged: @escaping (Bool) -> Void) {
        self.title = title
        self._value = value
        self.range = range
        self.label = label
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
                Text(label(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 54, alignment: .trailing)
            }
        }
    }
}
