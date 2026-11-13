import SwiftUI
import UniformTypeIdentifiers

/// The sections of Settings, in the order of the dock that switches between them.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general, dock, appearance, profiles, windows, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .dock: "Dock"
        case .appearance: "Appearance"
        case .profiles: "Profiles"
        case .windows: "Windows"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .dock: "dock.rectangle"
        case .appearance: "paintpalette.fill"
        case .profiles: "square.stack.3d.up.fill"
        case .windows: "macwindow"
        case .about: "info.circle.fill"
        }
    }
}

/// Which section Settings shows, and which dock tile the pointer is over. Kept outside the views, which hold no
/// `@State` (the Command Line Tools ship no plugin for the macOS 27 SDK's `@State` macro).
@Observable
final class SettingsNavigation {
    var pane: SettingsPane = .general
    var hovered: SettingsPane?
}

/// Max's settings: a 4:3 window with the current section above a dock of all of them.
struct SettingsView: View {
    @Bindable var store: SettingsStore
    let navigation: SettingsNavigation
    let loginItem: LoginItemSettings
    let skin: DockSkinTracker
    let dockSize: DockSize
    let pinner: DockPinner
    let trash: TrashWatcher
    let profiles: DockProfiles
    let windowCorners: WindowCornerOverride

    var body: some View {
        VStack(spacing: 0) {
            pane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            SettingsDock(navigation: navigation)
        }
        .frame(width: 720, height: 540)
        .background(ThemeBackground())
        .tint(MaxTheme.accent)
        .preferredColorScheme(colorScheme)
        .navigationTitle(navigation.pane.title)
    }

    @ViewBuilder private var pane: some View {
        switch navigation.pane {
        case .general: GeneralPane(store: store, loginItem: loginItem, skin: skin)
        case .dock: DockPane(store: store, skin: skin, dockSize: dockSize, pinner: pinner, trash: trash)
        case .appearance: AppearancePane(store: store)
        case .profiles: ProfilesPane(profiles: profiles)
        case .windows: WindowsPane(windowCorners: windowCorners)
        case .about: AboutPane()
        }
    }

    private var colorScheme: ColorScheme? {
        switch store.configuration.settingsAppearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The bar along the bottom of Settings, a small Max: a tile per section in the icon's lavenders, a dot under the
/// open one, and its name on hover. ⌘1 to ⌘6 switch sections.
struct SettingsDock: View {
    let navigation: SettingsNavigation
    @Environment(\.colorScheme) private var colorScheme

    /// Light to dark, as on the app icon's bar.
    private static let tiles: [UInt32] = [0xDDD6FE, 0xC4B5FD, 0xA78BFA, 0x8B7CF6, 0x7462E0, 0x6D5BD0]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(SettingsPane.allCases.enumerated()), id: \.element) { index, pane in
                tile(pane, index: index)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                (colorScheme == .dark ? Color(hex: 0x0C0B14).opacity(0.85) : Color.white.opacity(0.65))
                Rectangle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08))
                    .frame(height: 1)
            }
        }
    }

    private func tile(_ pane: SettingsPane, index: Int) -> some View {
        let selected = navigation.pane == pane
        let hovered = navigation.hovered == pane
        let light = index < 3
        return Button {
            navigation.pane = pane
        } label: {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(hex: Self.tiles[index]))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: pane.symbol)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(light ? Color(hex: 0x4C3FA0) : .white)
                    }
                    .shadow(color: .black.opacity(selected ? 0.25 : 0.12), radius: selected ? 4 : 2, y: 1)
                    .scaleEffect(hovered ? 1.08 : 1)
                Circle()
                    .fill(MaxTheme.accent)
                    .frame(width: 5, height: 5)
                    .opacity(selected ? 1 : 0)
            }
            .overlay(alignment: .top) {
                if hovered {
                    Text(pane.title)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.regularMaterial, in: Capsule())
                        .fixedSize()
                        .offset(y: -28)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.12), value: hovered)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
        .onHover { inside in
            if inside { navigation.hovered = pane } else if navigation.hovered == pane { navigation.hovered = nil }
        }
        .accessibilityLabel(pane.title)
    }
}

// MARK: - Panes

struct GeneralPane: View {
    @Bindable var store: SettingsStore
    let loginItem: LoginItemSettings
    let skin: DockSkinTracker

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dock Max")
                            .font(.title2.weight(.semibold))
                        Text(status)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            Section {
                Toggle("Show the bar", isOn: $store.configuration.isEnabled)
                Toggle("Launch at login", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
            }
            Section("Behavior") {
                Picker("Settings appearance", selection: $store.configuration.settingsAppearance) {
                    ForEach(OverlayConfiguration.SettingsAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Animate changes", isOn: $store.configuration.animationsEnabled)
                Toggle("Toggle the bar with \(GlobalHotKey.Shortcut.toggleOverlay.display)", isOn: $store.configuration.globalShortcutEnabled)
            }
            Section {
                LabeledContent("All settings") {
                    Button("Reset to Defaults") { store.resetToDefaults() }
                }
            }
        }
        .themedForm()
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

extension GeneralPane {
    fileprivate var status: String {
        let configuration = store.configuration
        if !configuration.isEnabled { return "The bar is off" }
        if configuration.skinsDock { return skin.isTrusted ? "Drawing over the Dock" : "Waiting for Accessibility access" }
        return "Behind the Dock"
    }
}

struct DockPane: View {
    @Bindable var store: SettingsStore
    let skin: DockSkinTracker
    let dockSize: DockSize
    let pinner: DockPinner
    let trash: TrashWatcher

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
                Text("Dock Max covers Apple's Dock and draws its icons exactly where the Dock does, so no floating pill shows. The Dock still handles clicks, menus, labels, and drags. Dock Max uses Accessibility access to read where the Dock draws its items, and to keep the Dock on the display you choose below.")
            }

            Section {
                if let tileSize = dockSize.tileSize {
                    SettingSlider("Dock size", value: Binding(get: { tileSize }, set: { dockSize.set($0.rounded()) }),
                                  in: DockGeometry.tileSizeRange, label: points)
                }
                if skins {
                    SettingSlider("Icon size", value: config.iconScale, in: OverlayConfiguration.iconScaleRange,
                                  label: percent, onEditingChanged: setInteracting)
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
                     ? "Dock size resizes the Dock itself, and windows always stop above it. A full Dock is already shrunk to fit the screen, so it can only get smaller. Icon size scales the icons Dock Max draws without changing the Dock's spacing. Extra height makes the bar taller than the Dock with the icons kept centered; windows can extend under the extra height."
                     : "Dock size resizes the Dock itself. Match Dock sizes the bar to the strip macOS reserves for the Dock.")
            }

            Section {
                Toggle("Running indicators", isOn: config.showsIndicators)
                Toggle("Mark the frontmost app", isOn: config.marksFrontmostApp)
                    .disabled(!store.configuration.showsIndicators)
                Toggle("Badges", isOn: config.showsBadges)
                Toggle("Bounce while apps open", isOn: config.bouncesOnLaunch)
                LabeledContent("Full Trash icon") {
                    if trash.hasAccess {
                        Label("On", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Allow Full Disk Access…", action: trash.openFullDiskAccessSettings)
                    }
                }
            } header: {
                Text("Icons")
            } footer: {
                Text("Dock Max draws these while it draws over the Dock. It also shows today's date on Calendar. Showing a full Trash needs Full Disk Access, because macOS protects the Trash folder.")
            }
            .disabled(!skins)

            Section {
                Toggle("Shift icons slightly over time", isOn: config.driftsIcons)
                Toggle("Dim the bar when idle", isOn: config.dimsWhenIdle)
                SettingSlider("After", value: config.idleDimMinutes, in: OverlayConfiguration.idleDimMinutesRange,
                              label: { "\(Int($0.rounded())) min" })
                    .disabled(!store.configuration.dimsWhenIdle)
            } header: {
                Text("Screen Care")
            } footer: {
                Text("A bar that never moves can leave a ghost on LCDs and burn in on OLEDs. Dock Max moves its icons a pixel every few minutes, too little to notice, and can darken the bar while you're away.")
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
        .themedForm()
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
            return "Push the pointer against the bottom of the chosen display once to move the Dock there. Dock Max then keeps it there by stopping the pointer just short of the other displays' Dock edges."
        }
        return "Dock Max keeps the Dock here by stopping the pointer just short of the other displays' Dock edges, where pushing would move it."
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
        .themedForm()
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
                        Button("Relaunch Apps…") { windowCorners.prepareRelaunch() }
                    }
                }
            } header: {
                Text("Window Corners")
            } footer: {
                Text("Sets the corner radius of every app's windows; macOS uses 16 pt. Apps pick it up when they reopen. This relies on an undocumented macOS setting that a future update could change.")
            }

            Section {
                ForEach(windowCorners.exceptions) { exception in
                    HStack(spacing: 8) {
                        if let url = exception.url {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        Text(exception.name)
                        if exception.isSandboxed {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.secondary)
                                .help("This app runs in a sandbox and may not pick up its exception.")
                        }
                        Spacer()
                        Picker("Radius", selection: Binding(
                            get: { exception.radius },
                            set: { windowCorners.setException(exception.id, radius: $0) }
                        )) {
                            Text("Square").tag(0.0)
                            ForEach([4.0, 8.0, 12.0], id: \.self) { Text("\(Int($0)) pt").tag($0) }
                            Text("16 pt (macOS)").tag(WindowCornerRadius.systemDefault)
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button("Relaunch", systemImage: "arrow.clockwise") { windowCorners.prepareRelaunch(only: exception.id) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .help("Relaunch \(exception.name)")
                        Button("Remove", systemImage: "minus.circle") { windowCorners.removeException(exception.id) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .help("Remove the exception")
                    }
                }
                Button("Add App…", action: chooseApps)
            } header: {
                Text("Exceptions")
            } footer: {
                Text("Give an app its own radius instead of the one above. Sandboxed apps, like most App Store apps, keep their own copy of settings, so an exception may not reach them.")
            }
        }
        .themedForm()
        .alert("Relaunch \(windowCorners.pendingRelaunch.count) Apps?", isPresented: Binding(
            get: { !windowCorners.pendingRelaunch.isEmpty },
            set: { if !$0 { windowCorners.cancelRelaunch() } }
        )) {
            Button("Relaunch", action: windowCorners.confirmRelaunch)
            Button("Cancel", role: .cancel, action: windowCorners.cancelRelaunch)
        } message: {
            Text("Dock Max will quit and reopen \(windowCorners.pendingRelaunch.map(\.name).formatted()). Apps with unsaved changes ask you to save first, and quitting Terminal ends anything running in it.")
        }
    }

    private func cornerRadiusLabel(_ value: Double) -> String {
        value == 0 ? "Square" : "\(Int(value)) pt"
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        if panel.runModal() == .OK { windowCorners.addExceptions(panel.urls) }
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
            Text("Dock Max")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            // A bright violet sample wallpaper, so the bar stands out in light and dark windows alike.
            LinearGradient(colors: MaxTheme.wallpaper, startPoint: .topLeading, endPoint: .bottomTrailing)
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
                    // Resolved, so symlinked apps (like Safari) don't get an alias arrow.
                    Image(nsImage: NSWorkspace.shared.icon(forFile: URL(fileURLWithPath: path).resolvingSymlinksInPath().path))
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
                message = "macOS needs you to approve Dock Max under System Settings › General › Login Items."
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

// MARK: - Theme

/// Colors from the app icon: a deep violet desktop with lavender tiles. Dark mode takes them as they are; light mode
/// keeps the violet accent over a pale lavender wash.
enum MaxTheme {
    static let desktop = [Color(hex: 0x2A2350), Color(hex: 0x1A1530), Color(hex: 0x2B1838)]
    static let wash = [Color(hex: 0xF8F6FF), Color(hex: 0xF0EBFD), Color(hex: 0xF7EFFA)]
    static let wallpaper = [Color(hex: 0x5A6BF0), Color(hex: 0x7B55D6), Color(hex: 0xB65FC2)]

    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(hex: 0xA78BFA) : NSColor(hex: 0x6D5BD0)
    })
}

/// The window background: the icon's desktop in dark mode, a lavender wash in light mode.
struct ThemeBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(colors: colorScheme == .dark ? MaxTheme.desktop : MaxTheme.wash, startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

extension View {
    /// A grouped form laid over the theme's background.
    func themedForm() -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(ThemeBackground())
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

private extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}
