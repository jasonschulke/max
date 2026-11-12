import SwiftUI

/// Max's settings: one tab per area, each a grouped form.
struct SettingsView: View {
    @Bindable var store: SettingsStore
    let loginItem: LoginItemSettings
    let skin: DockSkinTracker
    let dockSize: DockSize
    let pinner: DockPinner
    let dockEditor: DockEditor
    let windowCorners: WindowCornerOverride

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralPane(store: store, loginItem: loginItem)
            }
            Tab("Dock", systemImage: "dock.rectangle") {
                DockPane(store: store, skin: skin, dockSize: dockSize, pinner: pinner)
            }
            Tab("Appearance", systemImage: "paintpalette") {
                AppearancePane(store: store)
            }
            Tab("Dock Items", systemImage: "square.grid.3x1.below.line.grid.1x2") {
                DockEditorView(editor: dockEditor)
                    .frame(height: 600)
            }
            Tab("Windows", systemImage: "macwindow") {
                WindowsPane(windowCorners: windowCorners)
            }
            Tab("About", systemImage: "info.circle") {
                AboutPane()
            }
        }
        .frame(width: 540)
    }
}

// MARK: - Panes

struct GeneralPane: View {
    @Bindable var store: SettingsStore
    let loginItem: LoginItemSettings

    var body: some View {
        Form {
            Section {
                Toggle("Show the bar", isOn: $store.configuration.isEnabled)
                Toggle("Launch at login", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
            }
            Section("Behavior") {
                Toggle("Animate changes", isOn: $store.configuration.animationsEnabled)
                Toggle("Toggle the bar with \(GlobalHotKey.Shortcut.toggleOverlay.display)", isOn: $store.configuration.globalShortcutEnabled)
            }
            Section {
                LabeledContent("All settings") {
                    Button("Reset to Defaults") { store.resetToDefaults() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 340)
        .onAppear { loginItem.refresh() }
        .alert("Launch at Login", isPresented: Binding(
            get: { loginItem.message != nil },
            set: { if !$0 { loginItem.message = nil } }
        )) {
            Button("Open Login Items") { LaunchAtLogin.openSystemSettings() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginItem.message ?? "")
        }
    }
}

struct DockPane: View {
    @Bindable var store: SettingsStore
    let skin: DockSkinTracker
    let dockSize: DockSize
    let pinner: DockPinner

    private var config: Binding<OverlayConfiguration> { $store.configuration }
    private var skins: Bool { store.configuration.skinsDock }

    var body: some View {
        Form {
            Section {
                Toggle("Draw over the Dock", isOn: config.skinsDock)
                if skins {
                    LabeledContent("Accessibility access") {
                        if skin.isTrusted {
                            Label("Granted", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.secondary)
                        } else {
                            Button("Grant Access…", action: skin.requestAccess)
                        }
                    }
                }
            } footer: {
                Text("Max covers Apple's Dock and draws its icons exactly where the Dock does, so no floating pill shows. The Dock still handles clicks, menus, labels, and drags. Max uses Accessibility access to read where the Dock draws its items, and to keep the Dock on the display you choose below.")
            }

            Section {
                if let tileSize = dockSize.tileSize {
                    SettingSlider("Dock size", value: Binding(get: { tileSize }, set: { dockSize.set($0.rounded()) }),
                                  in: DockGeometry.tileSizeRange, label: points)
                }
                if skins {
                    SettingSlider("Extra height", value: Binding(
                        get: { max(0, store.configuration.heightAdjustment) },
                        set: { store.configuration.heightAdjustment = $0.rounded() }
                    ), in: 0...40, label: points, onEditingChanged: setInteracting)
                } else {
                    Picker("Bar height", selection: config.heightMode) {
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
                }
            } header: {
                Text("Size")
            } footer: {
                Text(skins
                     ? "Dock size resizes the Dock itself, and windows always stop above it. A full Dock is already shrunk to fit the screen, so it can only get smaller. Extra height makes the bar taller than the Dock with the icons kept centered; windows can extend under the extra height."
                     : "Dock size resizes the Dock itself. Match Dock sizes the bar to the strip macOS reserves for the Dock.")
            }

            Section {
                Picker("Keep the Dock on", selection: config.pinnedDisplay) {
                    Text("Any display").tag(String?.none)
                    ForEach(pinner.displays) { display in
                        Text(display.name).tag(String?.some(display.id))
                    }
                }
                .disabled(!pinner.separateSpaces || pinner.displays.count < 2)
                if let current = pinner.dockDisplay {
                    LabeledContent("The Dock is on", value: current.name)
                }
            } header: {
                Text("Display")
            } footer: {
                Text(displayFooter)
            }

            Section("Auto-Hide") {
                Toggle("Follow the Dock when it auto-hides", isOn: config.mirrorsDockAutoHide)
            }
        }
        .formStyle(.grouped)
        .frame(height: 620)
        .onAppear { pinner.refresh() }
    }

    private var displayFooter: String {
        if pinner.displays.count < 2 {
            return "Connect another display to choose where the Dock stays."
        }
        if !pinner.separateSpaces {
            return "The Dock stays on the main display while \u{201C}Displays have separate Spaces\u{201D} is off in Desktop & Dock settings."
        }
        guard let pinned = store.configuration.pinnedDisplay else {
            return "The Dock moves to whichever display you push the pointer against the bottom of. Choose a display to keep it there."
        }
        if !pinner.isEnforcing {
            return "Keeping the Dock in place needs Accessibility access."
        }
        if pinner.dockDisplay?.id != pinned {
            return "Push the pointer against the bottom of the chosen display once to move the Dock there. Max then keeps it there by stopping the pointer just short of the other displays' Dock edges."
        }
        return "Max keeps the Dock here by stopping the pointer just short of the other displays' Dock edges, where pushing would move it."
    }

    private func setInteracting(_ interacting: Bool) {
        store.isInteracting = interacting
    }
}

struct AppearancePane: View {
    @Bindable var store: SettingsStore

    private var config: Binding<OverlayConfiguration> { $store.configuration }
    private var configuration: OverlayConfiguration { store.configuration }

    var body: some View {
        Form {
            Section {
                BarPreview(configuration: configuration)
            }

            Section {
                Picker("Style", selection: config.style) {
                    ForEach(OverlayConfiguration.Style.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if configuration.style == .blur {
                    Picker("Blur material", selection: config.blurMaterial) {
                        ForEach(OverlayConfiguration.BlurMaterial.allCases) { Text($0.title).tag($0) }
                    }
                }
                if !(configuration.skinsDock && configuration.style == .solid) {
                    SettingSlider(configuration.skinsDock ? "Material opacity" : "Opacity", value: config.opacity,
                                  in: OverlayConfiguration.opacityRange, label: percent, onEditingChanged: setInteracting)
                }
                SettingSlider("Corner radius", value: config.cornerRadius, in: OverlayConfiguration.cornerRadiusRange,
                              label: points, onEditingChanged: setInteracting)
            } header: {
                Text("Material")
            } footer: {
                if configuration.skinsDock {
                    Text("Drawing over the Dock, the bar is opaque so the Dock never shows through; opacity fades the material over the bar's color.")
                }
            }

            Section {
                Toggle("Custom color", isOn: config.tint.isEnabled)
                Group {
                    ColorPicker("Color", selection: tintColor, supportsOpacity: false)
                    SettingSlider("Intensity", value: config.tint.strength, in: OverlayConfiguration.tintStrengthRange,
                                  label: percent, onEditingChanged: setInteracting)
                    Toggle("Fade toward the screen", isOn: config.tint.fadesUpward)
                }
                .disabled(!configuration.tint.isEnabled)
            } header: {
                Text("Color")
            } footer: {
                Text(configuration.skinsDock || configuration.style == .solid
                     ? "Colors the bar itself, under the material."
                     : "Washes over the material.")
            }
        }
        .formStyle(.grouped)
        .frame(height: 640)
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
}

struct WindowsPane: View {
    let windowCorners: WindowCornerOverride

    var body: some View {
        Form {
            Section {
                Toggle("Custom window corners", isOn: Binding(
                    get: { windowCorners.isOverridden },
                    set: { windowCorners.setOverridden($0) }
                ))
                if let radius = windowCorners.radius {
                    SettingSlider("Radius", value: Binding(
                        get: { radius },
                        set: { windowCorners.set(radius: $0.rounded()) }
                    ), in: WindowCornerRadius.range, label: cornerRadiusLabel)
                }
                LabeledContent("Apply to open apps") {
                    HStack {
                        Button("Relaunch Finder", action: windowCorners.relaunchFinder)
                        Button("Relaunch Apps…", action: windowCorners.prepareRelaunch)
                    }
                }
            } header: {
                Text("Window Corners")
            } footer: {
                Text("Sets the corner radius of every app's windows; macOS uses 16 pt. Apps pick it up when they reopen. This relies on an undocumented macOS setting that a future update could change.")
            }
        }
        .formStyle(.grouped)
        .frame(height: 300)
        .alert("Relaunch \(windowCorners.pendingRelaunch.count) Apps?", isPresented: Binding(
            get: { !windowCorners.pendingRelaunch.isEmpty },
            set: { if !$0 { windowCorners.cancelRelaunch() } }
        )) {
            Button("Relaunch", action: windowCorners.confirmRelaunch)
            Button("Cancel", role: .cancel, action: windowCorners.cancelRelaunch)
        } message: {
            Text("Max will quit and reopen \(windowCorners.pendingRelaunch.map(\.name).formatted()). Apps with unsaved changes ask you to save first, and quitting Terminal ends anything running in it.")
        }
    }

    private func cornerRadiusLabel(_ value: Double) -> String {
        value == 0 ? "Square" : "\(Int(value)) pt"
    }
}

struct AboutPane: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
            Text("Max")
                .font(.largeTitle.weight(.semibold))
            Text(version)
                .foregroundStyle(.secondary)
            Text("A full-width Dock for macOS.")
                .padding(.top, 4)
            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/jasonschulke/max")!)
                Link("Project Page", destination: URL(string: "https://jasonschulke.com/projects/max")!)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
    }
}

// MARK: - Bar preview

/// A small picture of the bar with the current style, color, and corner radius over a sample desktop.
private struct BarPreview: View {
    let configuration: OverlayConfiguration

    private static let apps = [
        "/System/Library/CoreServices/Finder.app", "/Applications/Safari.app", "/System/Applications/Messages.app",
        "/System/Applications/Mail.app", "/System/Applications/Calendar.app", "/System/Applications/Notes.app",
        "/System/Applications/Music.app", "/System/Applications/System Settings.app",
    ]
    /// The preview's bar is drawn at this fraction of the real bar's size.
    private let scale = 0.6

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(red: 0.27, green: 0.33, blue: 0.56), Color(red: 0.55, green: 0.42, blue: 0.62), Color(red: 0.86, green: 0.58, blue: 0.47)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            bar
        }
        .frame(height: 128)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
    }

    private var radius: CGFloat { configuration.cornerRadius * scale }
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: radius, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: radius)
    }
    private var opaque: Bool { configuration.skinsDock || configuration.style == .solid }
    private var tint: OverlayConfiguration.Tint { configuration.tint }

    private var bar: some View {
        ZStack {
            if opaque {
                shape.fill(Color(nsColor: .windowBackgroundColor))
                if tint.isEnabled { shape.fill(tintFill) }
            }
            material
                .opacity(configuration.style == .solid ? 0 : configuration.opacity)
            if !opaque, tint.isEnabled {
                shape.fill(tintFill)
                    .opacity(configuration.opacity)
            }
            HStack(spacing: 5) {
                ForEach(Self.apps, id: \.self) { path in
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .frame(width: 26, height: 26)
                }
            }
        }
        .frame(height: 34)
    }

    @ViewBuilder private var material: some View {
        switch configuration.style {
        case .glass: shape.fill(.clear).glassEffect(.regular, in: shape)
        case .clearGlass: shape.fill(.clear).glassEffect(.clear, in: shape)
        case .blur: shape.fill(.ultraThinMaterial)
        case .solid: shape.fill(.clear)
        }
    }

    private var tintFill: AnyShapeStyle {
        let color = tint.color.swiftUIColor.opacity(tint.strength)
        if tint.fadesUpward {
            return AnyShapeStyle(LinearGradient(colors: [color, color.opacity(0)], startPoint: .bottom, endPoint: .top))
        }
        return AnyShapeStyle(color)
    }
}

// MARK: - Shared parts

/// Launch-at-login state for the settings form. Lives outside the view, which keeps no `@State`:
/// the Command Line Tools ship no plugin for the macOS 27 SDK's `@State` macro.
@Observable
final class LoginItemSettings {
    private(set) var isEnabled = LaunchAtLogin.isEnabled
    /// Shown in an alert when a change needs the user's attention.
    var message: String?

    func refresh() {
        isEnabled = LaunchAtLogin.isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        guard enabled != LaunchAtLogin.isEnabled else { return }
        do {
            try LaunchAtLogin.setEnabled(enabled)
            if enabled, LaunchAtLogin.requiresApproval {
                message = "macOS needs you to approve Max under System Settings › General › Login Items."
            }
        } catch {
            isEnabled = LaunchAtLogin.isEnabled
            message = "Could not \(enabled ? "enable" : "disable") launch at login.\n\n\(error.localizedDescription)"
        }
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
         label: @escaping (Double) -> String, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
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

private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
private func points(_ value: Double) -> String { "\(Int(value.rounded())) pt" }
private func signedPoints(_ value: Double) -> String {
    let rounded = Int(value.rounded())
    return rounded > 0 ? "+\(rounded) pt" : "\(rounded) pt"
}
