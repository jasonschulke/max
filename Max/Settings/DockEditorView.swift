import SwiftUI
import UniformTypeIdentifiers

/// Apple's Dock items, for reordering, adding, and removing. Apply writes them back and restarts the Dock.
struct DockEditorView: View {
    @Bindable var editor: DockEditor

    var body: some View {
        VStack(spacing: 0) {
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

            Divider()

            HStack {
                Menu("Add") {
                    Button("App…", action: chooseApps)
                    Button("Folder…", action: chooseFolders)
                    Divider()
                    Button("Spacer") { editor.addSpacer(small: false) }
                    Button("Small Spacer") { editor.addSpacer(small: true) }
                }
                .fixedSize()
                Button("Remove") { editor.removeSelected() }
                    .disabled(editor.selection.isEmpty)
                Menu("More") {
                    Button("Reload from the Dock") { editor.reload() }
                    Button("Restore the Dock from Before Max's Edits") { editor.restoreBackup() }
                        .disabled(!editor.hasBackup)
                }
                .fixedSize()
                Spacer()
                Button("Apply") { editor.apply() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!editor.hasChanges)
            }
            .padding(12)

            Text("Drag to reorder. Apply restarts the Dock to load the changes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding([.horizontal, .bottom], 12)
        }
        .frame(minWidth: 380, minHeight: 520)
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
