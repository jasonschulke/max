import SwiftUI
import UniformTypeIdentifiers

/// Apple's Dock items, for reordering, adding, and removing. Save writes them back and restarts the Dock.
struct DockEditorView: View {
    @Bindable var editor: DockEditor

    var body: some View {
        VStack(spacing: 0) {
            DockStrip(editor: editor)
                .padding([.horizontal, .top], 16)
                .padding(.bottom, 10)

            List(selection: $editor.selection) {
                Section("Apps") {
                    ForEach(editor.apps) { DockEntryRow(entry: $0) }
                        .onMove { editor.move(in: .apps, from: $0, to: $1) }
                }
                Section("Folders") {
                    ForEach(editor.others) { DockEntryRow(entry: $0) }
                        .onMove { editor.move(in: .others, from: $0, to: $1) }
                }
            }
            .onDeleteCommand { editor.removeSelected() }
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Menu {
                    Button("App…", action: chooseApps)
                    Button("Folder…", action: chooseFolders)
                    Divider()
                    Button("Spacer") { editor.addSpacer(small: false) }
                    Button("Small Spacer") { editor.addSpacer(small: true) }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .fixedSize()
                Button("Remove", systemImage: "minus") { editor.removeSelected() }
                    .disabled(editor.selection.isEmpty)
                Menu("Profiles") {
                    ForEach(editor.profileNames, id: \.self) { name in
                        Menu(name) {
                            Button("Put on the Dock") { editor.applyProfile(named: name) }
                            Button("Delete") { editor.deleteProfile(named: name) }
                        }
                    }
                    if !editor.profileNames.isEmpty { Divider() }
                    Button("Save as Profile…") { editor.isNamingProfile = true }
                }
                .fixedSize()
                Menu("More") {
                    Button("Reload from the Dock") { editor.reload() }
                    Button("Restore the Dock from Before Max's Edits") { editor.restoreBackup() }
                        .disabled(!editor.hasBackup)
                }
                .fixedSize()
                Spacer()
                Button("Revert") { editor.reload() }
                    .disabled(!editor.hasChanges)
                Button("Save") { editor.apply() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!editor.hasChanges)
            }
            .padding(12)

            Text("Drag rows to rearrange. Save restarts the Dock to apply your changes; the first save keeps a backup of your original Dock.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .bottom], 12)
        }
        .background(ThemeBackground())
        .onAppear {
            if !editor.hasChanges { editor.reload() }
        }
        .alert("Save Dock Profile", isPresented: $editor.isNamingProfile) {
            TextField("Name", text: $editor.newProfileName)
            Button("Save") { editor.saveProfile(named: editor.newProfileName) }
            Button("Cancel", role: .cancel) { editor.newProfileName = "" }
        } message: {
            Text("Saves the arrangement shown here, so you can switch back to it from here or the menu bar.")
        }
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        if panel.runModal() == .OK { editor.addApps(panel.urls) }
    }

    private func chooseFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        if panel.runModal() == .OK { editor.addFolders(panel.urls) }
    }
}

/// The Dock as it will look after saving, scaled to fit: icons in order, spacers as gaps. Clicking an icon selects its row.
private struct DockStrip: View {
    @Bindable var editor: DockEditor

    private let maxIcon: CGFloat = 32
    private let inset: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let size = iconSize(fitting: proxy.size.width - 2 * inset)
            HStack(spacing: 0) {
                ForEach(editor.apps) { tile($0, size: size) }
                Rectangle()
                    .fill(.separator)
                    .frame(width: 1, height: size * 0.8)
                    .frame(width: size / 2)
                ForEach(editor.others) { tile($0, size: size) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 52)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Spacers take a full icon's width, small spacers and the separator half of one, as in the Dock.
    private func iconSize(fitting width: CGFloat) -> CGFloat {
        let units = (editor.apps + editor.others).reduce(0.5) { total, entry in
            if case .smallSpacer = entry.tile { return total + 0.5 }
            return total + 1
        }
        return max(8, min(maxIcon, width / units))
    }

    @ViewBuilder private func tile(_ entry: DockEditor.Entry, size: CGFloat) -> some View {
        let selected = editor.selection.contains(entry.id)
        let icon = size * 0.9
        Group {
            switch entry.tile {
            case .app(let url, _), .folder(let url):
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: icon, height: icon)
            case .spacer:
                Color.clear.frame(width: icon, height: icon)
            case .smallSpacer:
                Color.clear.frame(width: icon / 2, height: icon)
            case .other:
                Image(systemName: "questionmark.square.dashed")
                    .resizable()
                    .frame(width: icon, height: icon)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: entry.tile == .smallSpacer ? size / 2 : size, height: size)
        .background(selected ? Color.accentColor.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: size * 0.22))
        .help(entry.title)
        .onTapGesture { editor.selection = [entry.id] }
    }
}

private struct DockEntryRow: View {
    let entry: DockEditor.Entry

    var body: some View {
        HStack(spacing: 8) {
            icon
                .frame(width: 20, height: 20)
            Text(entry.title)
                .foregroundStyle(isPlaceholder ? .secondary : .primary)
        }
    }

    private var isPlaceholder: Bool {
        switch entry.tile {
        case .app, .folder: false
        case .spacer, .smallSpacer, .other: true
        }
    }

    @ViewBuilder private var icon: some View {
        switch entry.tile {
        case .app(let url, _), .folder(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
        case .spacer, .smallSpacer:
            Image(systemName: "rectangle.dashed")
                .foregroundStyle(.secondary)
        case .other:
            Image(systemName: "questionmark.square.dashed")
                .foregroundStyle(.secondary)
        }
    }
}
